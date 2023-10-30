defmodule TdDq.Search.Store do
  @moduledoc """
  Elasticsearch store implementation for Data Quality
  """

  @behaviour Elasticsearch.Store

  import Ecto.Query

  alias TdDd.DataStructures
  alias TdDd.Repo
  alias TdDq.Implementations
  alias TdDq.Implementations.Implementation
  alias TdDq.Rules.Rule

  @impl true
  def stream(Rule = schema) do
    schema
    |> where([r], is_nil(r.deleted_at))
    |> Repo.stream()
  end

  @impl true
  def stream(Implementation = schema) do
    schema
    |> Repo.stream()
    |> Repo.stream_preload(1000, :rule)
    |> Repo.stream_preload(1000,
      implementation_ref_struct: [:data_structures],
      data_structures: []
    )
    |> Stream.chunk_every(chunk_size())
    |> Stream.flat_map(&enrich_chunk_data_structures(&1))
  end

  def stream(Rule = schema, ids) do
    schema
    |> where([r], is_nil(r.deleted_at))
    |> where([r], r.id in ^ids)
    |> Repo.stream()
  end

  def stream(Implementation = schema, ids) do
    schema
    |> where([ri], ri.id in ^ids)
    |> Repo.stream()
    |> Repo.stream_preload(1000, :rule)
    |> Repo.stream_preload(1000,
      implementation_ref_struct: [:data_structures],
      data_structures: []
    )
    |> Stream.chunk_every(chunk_size())
    |> Stream.flat_map(&enrich_chunk_data_structures(&1))
  end

  @impl true
  def transaction(fun) do
    {:ok, result} = Repo.transaction(fun, timeout: :infinity)
    result
  end

  defp chunk_size, do: Application.get_env(__MODULE__, :chunk_size, 1000)

  defp enrich_chunk_data_structures(implementations_chunk) do
    structure_ids =
      implementations_chunk
      |> Enum.flat_map(fn implementation ->
        implementation
        |> Map.get(:implementation_ref_struct)
        |> Map.get(:data_structures)
        |> Enum.map(fn
          %{data_structure_id: structure_id} ->
            structure_id

          _ ->
            nil
        end)
      end)
      |> Enum.reject(&is_nil(&1))
      |> Enum.uniq()

    dsv_with_ds_index =
      DataStructures.enriched_structure_versions(
        data_structure_ids: structure_ids,
        content: :searchable,
        # Protected metadata is not indexed
        with_protected_metadata: false
      )
      |> Map.new(fn %{data_structure_id: structure_id} = dsv ->
        {structure_id, dsv}
      end)

    Enum.map(implementations_chunk, fn %{implementation_ref_struct: implementation_ref_struct} =
                                         implementation ->
      data_structures =
        implementation
        |> Map.get(:implementation_ref_struct)
        |> Map.get(:data_structures)
        |> Enum.map(fn %{data_structure_id: structure_id} = imp_data_structure ->
          dsv = Map.get(dsv_with_ds_index, structure_id, %{})

          path = get_apth(dsv)

          imp_data_structure
          |> Map.put(:current_version, Map.put(dsv, :path, path))
          |> Map.put(:data_structure, Map.get(dsv, :data_structure, %{}))
        end)

      new_imp_ref_struct = Map.put(implementation_ref_struct, :data_structures, data_structures)

      Map.put(implementation, :implementation_ref_struct, new_imp_ref_struct)
    end)
  end

  defp get_apth(dsv) do
    dsv
    |> Map.get(:path, [])
    |> Enum.map(fn %{"name" => name} -> name end)
  end
end
