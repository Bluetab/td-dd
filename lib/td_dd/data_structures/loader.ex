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
  alias TdDd.DataStructures.MerkleGraph
  alias TdDd.DataStructures.RelationTypes
  alias TdDd.DataStructures.StructureMetadata
  alias TdDd.Loader.FieldsAsStructures
  alias TdDd.Repo

  require Logger

  def load(structure_records, field_records, relation_records, audit_attrs, opts \\ []) do
    structure_count = Enum.count(structure_records)
    field_count = Enum.count(field_records)
    Logger.info("Starting bulk load (#{structure_count}SR+#{field_count}FR)")

    {structure_records, relation_records} =
      FieldsAsStructures.fields_as_structures(structure_records, field_records, relation_records)

    relation_records = RelationTypes.with_relation_types(relation_records)

    do_load(
      structure_records,
      relation_records,
      audit_attrs,
      opts[:external_id],
      opts[:parent_external_id]
    )
  end

  defp do_load(structure_records, relation_records, audit_attrs, nil, nil) do
    {:ok, graph} = MerkleGraph.new(structure_records, relation_records)
    Repo.transaction(fn -> do_load(structure_records, graph, audit_attrs) end)
  end

  defp do_load(
         structure_records,
         relation_records,
         audit_attrs,
         external_id,
         parent_external_id
       ) do
    {:ok, graph} = MerkleGraph.new(structure_records, relation_records)

    case MerkleGraph.root(graph) do
      ^external_id ->
        Repo.transaction(fn ->
          ancestor_records =
            external_id
            |> Ancestry.get_ancestor_records(parent_external_id)
            |> RelationTypes.with_relation_types()

          {:ok, graph} = MerkleGraph.add(graph, ancestor_records)

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
    %{updated: updated_metadata} = load_mutable_metadata(structure_records, audit_attrs)

    upserted_ids =
      [updated, inserted] |> Enum.flat_map(&Map.values/1) |> Enum.map(& &1.data_structure_id)

    Enum.uniq(discarded ++ upserted_ids ++ updated_metadata)
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
    reply = discard_structure_versions(system_id, group, external_ids, ts)
    ids = elem(reply, 1)

    unless ids == [] do
      discard_metadata_versions(ids, ts)
    end

    reply
  end

  defp discard_structure_versions(system_id, group, external_ids, ts) do
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

  defp discard_metadata_versions(ids, ts) do
    Repo.update_all(
      from(sm in StructureMetadata,
        join: ds in assoc(sm, :data_structure),
        where: is_nil(sm.deleted_at),
        where: ds.id in ^ids,
        update: [set: [deleted_at: ^ts]]
      ),
      []
    )
  end

  defp load_graph(graph, audit_attrs) do
    graph
    |> MerkleGraph.top_down()
    |> reduce(graph, audit_attrs)
  end

  defp reduce(external_ids, graph, audit_attrs, updated \\ %{}, inserted \\ %{})

  defp reduce([], graph, audit_attrs, updated, inserted) do
    update_count = Enum.count(updated)
    insert_count = Enum.count(inserted)
    Logger.info("Structures loaded (inserted=#{insert_count} updated=#{update_count})")
    rel_count = insert_relations(inserted, graph, audit_attrs)
    Logger.info("Relations loaded (inserted=#{rel_count})")
    %{updated: updated, inserted: inserted}
  end

  defp reduce([external_id | tail], graph, audit_attrs, %{} = updated, %{} = inserted) do
    attrs = MerkleGraph.get(graph, external_id)
    %{lhash: lhash, ghash: ghash} = attrs

    {tail, updated, inserted} =
      case DataStructures.get_latest_version_by_external_id(external_id, deleted: true) do
        nil ->
          Logger.debug("#{external_id} new")
          {:ok, new_version} = do_insert(attrs, audit_attrs)
          {tail, updated, Map.put(inserted, external_id, ids(new_version))}

        %{ghash: ^ghash, deleted_at: deleted_at} = current_version ->
          Logger.debug("#{external_id} ghash unchanged (discard)")
          {:ok, updated_version} = do_update(current_version)
          tail = prune(external_id, tail, graph, deleted_at)

          {tail,
           if(deleted_at, do: Map.put(updated, external_id, ids(updated_version)), else: updated),
           inserted}

        %{lhash: ^lhash, deleted_at: deleted_at} = current_version ->
          Logger.debug("#{external_id} ghash changed (update)")
          {:ok, updated_version} = do_update(current_version, attrs)

          {tail,
           if(deleted_at, do: Map.put(updated, external_id, ids(updated_version)), else: updated),
           inserted}

        current_version ->
          Logger.debug("#{external_id} lhash or hash changed (new version)")
          {:ok, new_version} = do_replace(current_version, attrs, audit_attrs)
          {tail, updated, Map.put(inserted, external_id, ids(new_version))}
      end

    reduce(tail, graph, audit_attrs, updated, inserted)
  end

  defp ids(%{id: id, data_structure_id: data_structure_id} = _dsv) do
    %{id: id, data_structure_id: data_structure_id}
  end

  defp prune(external_id, external_ids, graph, nil = _deleted_at) do
    descendents = MerkleGraph.descendents(graph, external_id)
    Logger.debug("#{external_id} pruned (#{Enum.count(descendents)} descendents)")
    Enum.reject(external_ids, &Enum.member?(descendents, &1))
  end

  defp prune(_external_id, external_ids, _graph, _deleted_at), do: external_ids

  defp insert_relations(%{} = inserted, _graph, _audit_attrs) when inserted == %{}, do: 0

  defp insert_relations(%{} = inserted, graph, %{ts: ts}) do
    inserted
    |> Enum.map(fn {external_id, %{id: id}} ->
      {id, MerkleGraph.in_edges(graph, external_id), MerkleGraph.out_edges(graph, external_id)}
    end)
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

  defp relation_attrs({id, in_edges, out_edges}, ts) do
    parent_rels = Enum.map(in_edges, &parent_rel(id, &1, ts))
    child_rels = Enum.map(out_edges, &child_rel(id, &1, ts))
    parent_rels ++ child_rels
  end

  defp parent_rel(child_id, %{v1: external_id, label: %{relation_type_id: type_id}}, ts) do
    %{id: parent_id} = DataStructures.get_latest_version_by_external_id(external_id)

    %{
      parent_id: parent_id,
      child_id: child_id,
      relation_type_id: type_id,
      inserted_at: ts,
      updated_at: ts
    }
  end

  defp child_rel(parent_id, %{v2: external_id, label: %{relation_type_id: type_id}}, ts) do
    %{id: child_id} = DataStructures.get_latest_version_by_external_id(external_id)

    %{
      parent_id: parent_id,
      child_id: child_id,
      relation_type_id: type_id,
      inserted_at: ts,
      updated_at: ts
    }
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

  defp load_mutable_metadata(records, audit_attrs) do
    do_load_mutable_metadata(records, audit_attrs)
  end

  defp do_load_mutable_metadata([], _), do: %{updated: []}

  defp do_load_mutable_metadata(records, audit_attrs) do
    reduce_metadata(records, audit_attrs)
  end

  defp reduce_metadata(records, audit_attrs, updated_ids \\ [])

  defp reduce_metadata([], _audit_attrs, updated_ids) do
    update_count = Enum.count(updated_ids)
    Logger.info("Metadata loaded (upserted=#{update_count})")
    %{updated: updated_ids}
  end

  defp reduce_metadata([record | tail], audit_attrs, updated_ids) do
    external_id = Map.get(record, :external_id)
    mutable_metadata = Map.get(record, :mutable_metadata)

    ids =
      external_id
      |> DataStructures.get_data_structure_by_external_id()
      |> update_metadata(mutable_metadata, audit_attrs)

    reduce_metadata(tail, audit_attrs, updated_ids ++ ids)
  end

  defp update_metadata(nil, _, _), do: []

  defp update_metadata(%DataStructure{id: id} = data_structure, mutable_metadata, audit_attrs) do
    id
    |> DataStructures.get_latest_metadata_version()
    |> create_metadata_version(mutable_metadata, data_structure, audit_attrs)
  end

  defp create_metadata_version(
         current_metadata,
         mutable_metadata,
         %DataStructure{id: id} = data_structure,
         %{ts: ts} = audit_attrs
       )
       when mutable_metadata == %{} or is_nil(mutable_metadata) do
    case current_metadata do
      %StructureMetadata{deleted_at: nil} ->
        DataStructures.update_structure_metadata(current_metadata, %{deleted_at: ts})
        update_structure(data_structure, audit_attrs)

        [id]

      _ ->
        []
    end
  end

  defp create_metadata_version(
         nil,
         %{} = mutable_metadata,
         %DataStructure{id: id} = data_structure,
         audit_attrs
       ) do
    insert_metadata_version(0, mutable_metadata, id)
    update_structure(data_structure, audit_attrs)

    [id]
  end

  defp create_metadata_version(
         %StructureMetadata{deleted_at: nil, fields: fields} = current_metadata,
         %{} = mutable_metadata,
         %DataStructure{id: id} = data_structure,
         %{ts: ts} = audit_attrs
       ) do
    if fields == mutable_metadata do
      []
    else
      insert_metadata_version(current_metadata.version + 1, mutable_metadata, id)
      DataStructures.update_structure_metadata(current_metadata, %{deleted_at: ts})
      update_structure(data_structure, audit_attrs)

      [id]
    end
  end

  defp create_metadata_version(
         %{version: current_metadata_version} = _current_metadata,
         mutable_metadata,
         %DataStructure{id: id} = data_structure,
         audit_attrs
       ) do
    insert_metadata_version(current_metadata_version + 1, mutable_metadata, id)
    update_structure(data_structure, audit_attrs)

    [id]
  end

  defp insert_metadata_version(version, fields, data_structure_id) do
    DataStructures.create_structure_metadata(%{
      version: version,
      data_structure_id: data_structure_id,
      fields: fields
    })
  end

  defp update_structure(data_structure, attrs) do
    data_structure
    |> DataStructure.update_changeset(attrs)
    |> Repo.update()
  end
end
