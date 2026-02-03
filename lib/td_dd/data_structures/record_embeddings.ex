defmodule TdDd.DataStructures.RecordEmbeddings do
  @moduledoc """
  Context to manage record embeddings
  """

  import Ecto.Query

  alias Ecto.Multi
  alias TdCluster.Cluster.TdAi.Indices
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructureQueries
  alias TdDd.DataStructures.DataStructureVersions.RecordEmbedding
  alias TdDd.DataStructures.DataStructureVersions.Workers.EmbeddingsUpsertBatch
  alias TdDd.DataStructures.Search.Indexer
  alias TdDd.Repo

  require Logger

  @batch_size Application.compile_env(:td_dd, :data_structure_record_embeddings_batch_size, 50)
  @default_delay_ms Application.compile_env(:td_dd, :record_embeddings_default_delay_ms, 500)
  @index_type "suggestions"

  def upsert_from_structures_async(data_structure_ids, opts \\ []) do
    case Indices.exists_enabled?(index_type: @index_type) do
      {:ok, true} ->
        delay_ms =
          Keyword.get(opts, :delay_ms, @default_delay_ms)

        Repo.transaction(fn ->
          data_structure_ids
          |> List.wrap()
          |> Stream.chunk_every(@batch_size)
          |> Stream.with_index()
          |> Stream.map(&build_embeddings_job(&1, delay_ms, opts))
          |> Oban.insert_all()
          |> Enum.to_list()
        end)

      _ ->
        :noop
    end
  end

  defp build_embeddings_job({ids, index}, delay_ms, opts) do
    job_opts =
      if delay_ms > 0 do
        schedule_in_seconds = div(index * delay_ms, 1000)
        Keyword.put(opts, :schedule_in, schedule_in_seconds)
      else
        opts
      end

    EmbeddingsUpsertBatch.new(%{"data_structure_ids" => ids}, job_opts)
  end

  def upsert_from_structures(data_structure_ids) do
    ## TODO TD-7555: Inconsistent behavior: Verify if the provider is correctly configured.
    case Indices.exists_enabled?(index_type: @index_type) do
      {:ok, true} ->
        now = DateTime.utc_now()

        records =
          data_structure_ids
          |> enriched_versions_for_embeddings()
          |> Enum.chunk_every(@batch_size)
          |> Enum.with_index()
          |> Enum.flat_map(&process_versions_batch/1)

        RecordEmbedding
        |> Repo.insert_all(records,
          placeholders: %{now: now},
          conflict_target: [:data_structure_version_id, :collection],
          on_conflict: {:replace, [:embedding, :dims, :updated_at]}
        )
        |> tap(fn _ -> Indexer.put_embeddings(data_structure_ids) end)

      error ->
        Logger.error("Error generating embeddings for data structures: #{inspect(error)}")
        error
    end
  end

  def upsert_outdated_async(opts \\ []) do
    case Indices.list(enabled: true, index_type: @index_type) do
      {:ok, [_ | _] = indices} ->
        indices
        |> Enum.map(& &1.collection_name)
        |> DataStructureQueries.data_structures_with_outdated_embeddings(opts)
        |> Repo.all()
        |> upsert_from_structures_async()

      _other ->
        :noop
    end
  end

  def delete_stale_record_embeddings do
    ## TODO TD-7555: Inconsistent behavior: Verify if the provider is correctly configured.
    case Indices.list(enabled: true, index_type: @index_type) do
      {:ok, [_ | _] = indices} ->
        collections = Enum.map(indices, & &1.collection_name)

        Multi.new()
        |> Multi.delete_all(:from_disabled_indices, fn _ ->
          RecordEmbedding
          |> where([re], re.collection not in ^collections)
          |> join(:inner, [re, dsv], dsv in assoc(re, :data_structure_version))
          |> select([re], re)
        end)
        |> Multi.delete_all(
          :from_deleted_data_structure_versions,
          fn _ ->
            RecordEmbedding
            |> join(:inner, [re, dsv], dsv in assoc(re, :data_structure_version))
            |> where([re, dsv], not is_nil(dsv.deleted_at))
            |> select([re], re)
          end
        )
        |> Repo.transaction()

      {:ok, []} ->
        Repo.delete_all(RecordEmbedding)

      _ ->
        :noop
    end
  end

  defp process_versions_batch({versions, batch_index}) do
    case DataStructures.embeddings(versions) do
      {:ok, embedding_by_collection} ->
        record_embeddings(embedding_by_collection, versions)

      {:error, error} ->
        Logger.error("Error generating embeddings for batch #{batch_index}: #{inspect(error)}")

        []
    end
  end

  defp enriched_versions_for_embeddings(data_structure_ids) do
    [data_structure_ids: data_structure_ids]
    |> DataStructureQueries.data_structure_version_embeddings()
    |> Repo.all()
    |> Enum.map(&DataStructures.enriched_structure_version(&1, content: :searchable))
  end

  defp record_embeddings(embedding_by_collection, data_structure_versions) do
    embedding_type = RecordEmbedding.__schema__(:type, :embedding)

    Enum.flat_map(embedding_by_collection, fn {collection_name, embeddings} ->
      data_structure_versions
      |> Enum.zip(embeddings)
      |> Enum.map(fn {data_structure_version, embedding} ->
        {:ok, cast_embedding} = Ecto.Type.cast(embedding_type, embedding)

        %{
          data_structure_version_id: data_structure_version.id,
          embedding: cast_embedding,
          dims: length(embedding),
          collection: collection_name,
          inserted_at: {:placeholder, :now},
          updated_at: {:placeholder, :now}
        }
      end)
    end)
  end
end
