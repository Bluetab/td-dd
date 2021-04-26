defmodule TdDd.Loader.Relations do
  @moduledoc """
  Loader multi support for inserting new data structure relations.
  """

  import Ecto.Query

  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureRelation
  alias TdDd.DataStructures.MerkleGraph
  alias TdDd.Repo

  def insert_new_relations(
        _repo,
        %{
          insert_versions: {_, inserted_versions},
          replace_versions: {_, replaced_versions},
          context: %{
            graph: graph,
            version_id_map: version_id_map
          }
        },
        ts
      ) do
    ids = Enum.map(inserted_versions ++ replaced_versions, & &1.id)

    DataStructure
    |> join(:inner, [ds], dsv in assoc(ds, :versions))
    |> distinct([ds], ds.external_id)
    |> order_by([ds, dsv], asc: ds.external_id, desc: dsv.version)
    |> where([_, dsv], dsv.id in ^ids)
    |> select([ds, dsv], {ds.external_id, dsv.id})
    |> Repo.all()
    |> Map.new()
    |> do_insert_relations(graph, version_id_map, ts)

    {:ok, []}
  end

  defp do_insert_relations(%{} = inserted, _graph, _version_id_map, _ts)
       when inserted == %{},
       do: 0

  defp do_insert_relations(%{} = inserted, graph, version_id_map, ts) do
    inserted
    |> Enum.map(fn {external_id, id} ->
      {id, MerkleGraph.in_edges(graph, external_id), MerkleGraph.out_edges(graph, external_id)}
    end)
    |> Enum.flat_map(&relation_attrs(&1, inserted, version_id_map, ts))
    |> Enum.uniq()
    |> do_insert_relations()
  end

  defp do_insert_relations(entries) do
    {count, _} = Repo.chunk_insert_all(DataStructureRelation, entries, chunk_size: 1000)
    count
  end

  defp relation_attrs({id, in_edges, out_edges}, inserted, version_id_map, ts) do
    parent_rels = Enum.map(in_edges, &parent_rel(id, &1, inserted, version_id_map, ts))
    child_rels = Enum.map(out_edges, &child_rel(id, &1, inserted, version_id_map, ts))
    parent_rels ++ child_rels
  end

  defp parent_rel(
         child_id,
         %{v1: external_id, label: %{relation_type_id: type_id}},
         inserted,
         version_id_map,
         ts
       ) do
    parent_id = Map.get(inserted, external_id, get_in(version_id_map, [external_id, :id]))

    %{
      parent_id: parent_id,
      child_id: child_id,
      relation_type_id: type_id,
      inserted_at: ts,
      updated_at: ts
    }
  end

  defp child_rel(
         parent_id,
         %{v2: external_id, label: %{relation_type_id: type_id}},
         inserted,
         version_id_map,
         ts
       ) do
    child_id = Map.get(inserted, external_id, get_in(version_id_map, [external_id, :id]))

    %{
      parent_id: parent_id,
      child_id: child_id,
      relation_type_id: type_id,
      inserted_at: ts,
      updated_at: ts
    }
  end
end
