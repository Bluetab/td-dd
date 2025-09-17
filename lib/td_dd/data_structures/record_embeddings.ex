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

  @batch_size 128

  def upsert_from_structures_async(data_structure_ids, opts \\ []) do
    case Indices.exists_enabled?() do
      {:ok, true} ->
        Repo.transaction(fn ->
          data_structure_ids
          |> List.wrap()
          |> Stream.chunk_every(@batch_size)
          |> Stream.map(&EmbeddingsUpsertBatch.new(%{"data_structure_ids" => &1}, opts))
          |> Oban.insert_all()
          |> Enum.to_list()
        end)

      _ ->
        :noop
    end
  end

  def upsert_from_structures(data_structure_ids) do
    case Indices.exists_enabled?() do
      {:ok, true} ->
        now = DateTime.utc_now()
        data_structure_versions = enriched_versions_for_embeddings(data_structure_ids)
        {:ok, embedding_by_collection} = DataStructures.embeddings(data_structure_versions)
        records = record_embeddings(embedding_by_collection, data_structure_versions)

        RecordEmbedding
        |> Repo.insert_all(records,
          placeholders: %{now: now},
          conflict_target: [:data_structure_version_id, :collection],
          on_conflict: {:replace, [:embedding, :dims, :updated_at]}
        )
        |> tap(fn _ -> Indexer.put_embeddings(data_structure_ids) end)

      _ ->
        :noop
    end
  end

  def upsert_outdated_async(opts \\ []) do
    case Indices.list(enabled: true) do
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
    case Indices.list(enabled: true) do
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

  defp enriched_versions_for_embeddings(data_structure_ids) do
    [data_structure_ids: data_structure_ids]
    |> DataStructureQueries.data_structure_version_embeddings()
    |> Repo.all()
    |> Enum.map(&DataStructures.enriched_structure_version(&1, content: :searchable))
  end

  defp record_embeddings(embedding_by_collection, data_structure_versions) do
    Enum.flat_map(embedding_by_collection, fn {collection_name, embeddings} ->
      data_structure_versions
      |> Enum.zip(embeddings)
      |> Enum.map(fn {data_structure_version, embedding} ->
        %{
          data_structure_version_id: data_structure_version.id,
          embedding: embedding,
          dims: length(embedding),
          collection: collection_name,
          inserted_at: {:placeholder, :now},
          updated_at: {:placeholder, :now}
        }
      end)
    end)
  end
end
