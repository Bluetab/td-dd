defmodule TdDd.Loader do
  @moduledoc """
  Bulk loader for data structure metadata
  """

  import Ecto.Query, warn: false

  alias TdDd.DataStructures
  alias TdDd.DataStructures.Ancestry
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureRelation
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.Graph
  alias TdDd.DataStructures.RelationTypes
  alias TdDd.Loader.FieldsAsStructures
  alias TdDd.Repo

  require Logger

  def load(graph, structure_records, field_records, relation_records, audit_attrs, opts \\ []) do
    structure_count = Enum.count(structure_records)
    field_count = Enum.count(field_records)
    Logger.info("Starting bulk load (#{structure_count}SR+#{field_count}FR)")

    {structure_records, relation_records} =
      FieldsAsStructures.fields_as_structures(structure_records, field_records, relation_records)

    default_relation_type = RelationTypes.get_default_relation_type()
    relation_types_id_map = RelationTypes.get_relation_type_name_to_id_map()

    relation_records =
      relation_records
      |> Enum.map(&{&1, get_relation_type(&1, relation_types_id_map, default_relation_type)})
      |> Enum.map(fn {rel, {rel_type_id, rel_type_name}} ->
        rel
        |> Map.put(:relation_type_id, rel_type_id)
        |> Map.put(:relation_type_name, rel_type_name)
      end)

    do_load(
      graph,
      structure_records,
      relation_records,
      audit_attrs,
      opts[:external_id],
      opts[:parent_external_id]
    )
  end

  defp get_relation_type(%{relation_type_name: ""}, _, default), do: {default.id, default.name}

  defp get_relation_type(%{relation_type_name: relation_type_name}, id_maps, _) do
    {Map.get(id_maps, relation_type_name), relation_type_name}
  end

  defp get_relation_type(_, _, default), do: {default.id, default.name}

  defp do_load(graph, structure_records, relation_records, audit_attrs, nil, nil) do
    {:ok, graph} = Graph.add(graph, structure_records, relation_records)
    Repo.transaction(fn -> do_load(structure_records, graph, audit_attrs) end)
  end

  defp do_load(
         graph,
         structure_records,
         relation_records,
         audit_attrs,
         external_id,
         parent_external_id
       ) do
    {:ok, graph} = Graph.add(graph, structure_records, relation_records)

    case Graph.root(graph) do
      ^external_id ->
        Repo.transaction(fn ->
          ancestor_records = Ancestry.get_ancestor_records(external_id, parent_external_id)
          {:ok, graph} = Graph.add(graph, ancestor_records)

          do_load(structure_records, graph, audit_attrs)
        end)

      nil ->
        {:error, :invalid_graph}

      _ ->
        {:error, :root_mismatch}
    end
  end

  defp do_load(structure_records, graph, %{ts: ts} = audit_attrs) do
    {discard_count, discarded} = discard_absent_structures(structure_records, ts)

    if discard_count > 0 do
      Logger.info("Discarded #{discard_count} structures")
    end

    %{updated: updated, inserted: inserted} = load_graph(graph, audit_attrs)

    Enum.uniq(updated ++ discarded ++ inserted)
  end

  defp discard_absent_structures(structure_records, ts) do
    structure_records
    |> Enum.group_by(
      fn %{group: group, system_id: system_id} -> {system_id, group} end,
      &Map.get(&1, :external_id)
    )
    |> Enum.map(&discard_absent_group_structures(&1, ts))
    |> Enum.reduce(fn {count1, ids1}, {count2, ids2} -> {count1 + count2, ids1 ++ ids2} end)
  end

  defp discard_absent_group_structures({{system_id, group}, external_ids}, ts) do
    Repo.update_all(
      from(dsv in DataStructureVersion,
        where: dsv.group == ^group,
        where: is_nil(dsv.deleted_at),
        join: ds in assoc(dsv, :data_structure),
        where: ds.system_id == ^system_id,
        where: ds.external_id not in ^external_ids,
        update: [set: [deleted_at: ^ts]],
        select: dsv.data_structure_id
      ),
      []
    )
  end

  defp load_graph(graph, audit_attrs) do
    graph
    |> Graph.top_down()
    |> reduce(graph, audit_attrs)
  end

  defp reduce(external_ids, graph, audit_attrs, updated_ids \\ [], inserted_ids \\ [])

  defp reduce([], graph, audit_attrs, updated_ids, inserted_ids) do
    update_count = Enum.count(updated_ids)
    insert_count = Enum.count(inserted_ids)
    Logger.info("Structures loaded (inserted=#{insert_count} updated=#{update_count})")
    rel_count = insert_relations(inserted_ids, graph, audit_attrs)
    Logger.info("Relations loaded (inserted=#{rel_count})")
    %{updated: updated_ids, inserted: inserted_ids}
  end

  defp reduce([external_id | tail], graph, audit_attrs, updated_ids, inserted_ids) do
    attrs = Graph.get(graph, external_id)
    %{lhash: lhash, ghash: ghash} = attrs

    {tail, updated, inserted} =
      case DataStructures.get_latest_version_by_external_id(external_id, deleted: true) do
        nil ->
          Logger.debug("#{external_id} new")
          {:ok, new_version} = do_insert(attrs, audit_attrs)
          {tail, [], [new_version]}

        %{ghash: ^ghash, deleted_at: deleted_at} = current_version ->
          Logger.debug("#{external_id} ghash unchanged (discard)")
          {:ok, updated_version} = do_update(current_version)
          tail = prune(external_id, tail, graph)
          {tail, if(is_nil(deleted_at), do: [], else: [updated_version]), []}

        %{lhash: ^lhash, deleted_at: deleted_at} = current_version ->
          Logger.debug("#{external_id} ghash changed (update)")
          {:ok, updated_version} = do_update(current_version, attrs)
          {tail, if(is_nil(deleted_at), do: [], else: [updated_version]), []}

        current_version ->
          Logger.debug("#{external_id} lhash or hash changed (new version)")
          {:ok, new_version} = do_replace(current_version, attrs, audit_attrs)

          # TODO: If/when we reindex versions instead of structures we should return the following:
          # {tail, [current_version], [new_version]}
          {tail, [], [new_version]}
      end

    reduce(
      tail,
      graph,
      audit_attrs,
      Enum.map(updated, & &1.data_structure_id) ++ updated_ids,
      Enum.map(inserted, & &1.data_structure_id) ++ inserted_ids
    )
  end

  defp prune(external_id, external_ids, graph) do
    descendents = Graph.descendents(graph, external_id)
    Logger.debug("#{external_id} pruned (#{Enum.count(descendents)} descendents)")
    Enum.reject(external_ids, &Enum.member?(descendents, &1))
  end

  defp insert_relations([], _graph, _audit_attrs), do: 0

  defp insert_relations(data_structure_ids, graph, %{ts: ts}) do
    from(ds in DataStructure,
      where: ds.id in ^data_structure_ids,
      select: ds.external_id
    )
    |> Repo.all()
    |> Enum.map(&{&1, Graph.parents(graph, &1), Graph.children(graph, &1)})
    |> Enum.flat_map(&relation_attrs(&1, ts))
    |> Enum.uniq()
    |> do_insert_relations()
  end

  defp do_insert_relations(entries) do
    entries
    |> Enum.chunk_every(1000)
    |> Enum.map(fn chunk -> Repo.insert_all(DataStructureRelation, chunk) end)
    |> Enum.map(fn {count, _} -> count end)
    |> Enum.sum()
  end

  defp get_structure_id_and_relation_type({external_id, [relation_type_id: relation_type_id, relation_type_name: _name]}) do
    structure_id =
      external_id
      |> DataStructures.get_latest_version_by_external_id()
      |> Map.get(:id)

    {structure_id, relation_type_id}
  end

  defp relation_attrs({external_id, parent_external_ids, child_external_ids}, ts) do
    %{id: id} = DataStructures.get_latest_version_by_external_id(external_id)

    parent_rels =
      parent_external_ids
      |> Enum.map(&get_structure_id_and_relation_type(&1))
      |> Enum.map(fn {external_id, relation_type_id} ->
        %{
          parent_id: external_id,
          child_id: id,
          inserted_at: ts,
          relation_type_id: relation_type_id,
          updated_at: ts
        }
      end)

    child_rels =
      child_external_ids
      |> Enum.map(&get_structure_id_and_relation_type(&1))
      |> Enum.map(fn {external_id, relation_type_id} ->
        %{
          parent_id: id,
          child_id: external_id,
          inserted_at: ts,
          relation_type_id: relation_type_id,
          updated_at: ts
        }
      end)

    parent_rels ++ child_rels
  end

  defp do_insert(attrs, audit_attrs) do
    %{id: data_structure_id} = do_insert_structure(attrs, audit_attrs)

    attrs =
      attrs
      |> Map.put(:version, 0)
      |> Map.put(:data_structure_id, data_structure_id)

    %DataStructureVersion{}
    |> DataStructureVersion.changeset(attrs)
    |> Repo.insert()
  end

  defp do_insert_structure(%{external_id: external_id} = attrs, audit_attrs) do
    case DataStructures.find_data_structure(%{external_id: external_id}) do
      nil ->
        %DataStructure{}
        |> DataStructure.changeset(Map.merge(attrs, audit_attrs))
        |> Repo.insert!()

      ds ->
        ds
    end
  end

  defp do_update(%DataStructureVersion{deleted_at: nil} = dsv) do
    {:ok, dsv}
  end

  defp do_update(%DataStructureVersion{} = dsv) do
    dsv
    |> DataStructureVersion.update_changeset(%{deleted_at: nil})
    |> Repo.update()
  end

  defp do_update(%DataStructureVersion{deleted_at: nil} = dsv, attrs) do
    dsv
    |> DataStructureVersion.update_changeset(attrs)
    |> Repo.update()
  end

  defp do_update(%DataStructureVersion{} = dsv, attrs) do
    attrs = Map.put(attrs, :deleted_at, nil)

    dsv
    |> DataStructureVersion.update_changeset(attrs)
    |> Repo.update()
  end

  defp do_replace(
         %DataStructureVersion{version: version, data_structure_id: data_structure_id} = current,
         attrs,
         %{ts: ts}
       ) do
    attrs =
      attrs
      |> Map.put(:version, version + 1)
      |> Map.put(:data_structure_id, data_structure_id)

    # soft-delete current version
    current
    |> DataStructureVersion.update_changeset(%{deleted_at: ts})
    |> Repo.update()

    # insert new version
    %DataStructureVersion{}
    |> DataStructureVersion.changeset(attrs)
    |> Repo.insert()
  end
end
