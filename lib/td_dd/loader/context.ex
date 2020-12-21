defmodule TdDd.Loader.Context do
  @moduledoc """
  Loader support to create a context which is used in `Ecto.Multi` operations.
  """
  import Ecto.Query

  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Repo

  @type context :: %{
          entries: [map],
          ghash: map,
          graph: map,
          lhash: map,
          structure_id_map: map,
          version_id_map: map
        }

  @spec create_context(atom, %{graph: Graph.t()}, map) :: {:ok, context()}
  def create_context(_repo, %{graph: graph} = _changes, audit), do: create_context(graph, audit)

  @spec create_context(atom, Graph.t(), map) :: {:ok, context()}
  def create_context(graph, audit) do
    %{external_ids: load_external_ids, ghash: load_ghashes, lhash: load_lhashes} =
      load_context(graph)

    structure_id_map =
      DataStructure
      |> where([ds], ds.external_id in ^load_external_ids)
      |> select([ds], {ds.external_id, ds.id})
      |> Repo.all()
      |> BiMap.new()

    data_structure_ids = BiMap.values(structure_id_map)

    dsvs =
      DataStructureVersion
      |> where([ds], ds.data_structure_id in ^data_structure_ids)
      |> distinct(:data_structure_id)
      |> order_by(asc: :data_structure_id, desc: :version)
      |> select([dsv], %{
        value: %{},
        id: dsv.id,
        deleted_at: dsv.deleted_at,
        lhash: dsv.lhash,
        ghash: dsv.ghash,
        data_structure_id: dsv.data_structure_id,
        version: dsv.version
      })
      |> Repo.all()

    existing_ghashes =
      dsvs
      |> Map.new(fn %{ghash: ghash, id: id, deleted_at: deleted_at} ->
        {ghash, %{id: id, deleted_at: deleted_at}}
      end)
      |> Map.take(Map.keys(load_ghashes))

    existing_lhashes =
      dsvs
      |> Map.new(fn %{lhash: lhash, id: id, deleted_at: deleted_at} ->
        {lhash, %{id: id, deleted_at: deleted_at}}
      end)
      |> Map.take(Map.keys(load_lhashes))

    version_id_map =
      Map.new(dsvs, fn %{data_structure_id: data_structure_id, id: id, version: version} ->
        {BiMap.fetch_key!(structure_id_map, data_structure_id), %{id: id, version: version}}
      end)

    entries =
      graph
      |> Graph.vertices(labels: true)
      |> Enum.map(fn {_external_id, %{record: record} = label} ->
        label
        |> Map.take([:hash, :lhash, :ghash])
        |> Map.merge(record)
        |> Map.merge(audit)
      end)

    {:ok,
     %{
       graph: graph,
       ghash: existing_ghashes,
       lhash: existing_lhashes,
       structure_id_map: BiMap.left(structure_id_map),
       version_id_map: version_id_map,
       entries: entries
     }}
  end

  defp load_context(graph) do
    hashes =
      graph
      |> Graph.vertices(labels: true)
      |> Enum.map(fn {ext_id, %{lhash: lhash, ghash: ghash}} ->
        %{lhash: lhash, ghash: ghash, external_id: ext_id}
      end)

    %{
      ghash: Map.new(hashes, fn %{ghash: ghash, external_id: ext_id} -> {ghash, ext_id} end),
      lhash: Map.new(hashes, fn %{lhash: lhash, external_id: ext_id} -> {lhash, ext_id} end),
      external_ids: Graph.vertices(graph)
    }
  end
end
