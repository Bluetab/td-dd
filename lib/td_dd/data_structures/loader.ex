defmodule TdDd.Loader do
  @moduledoc """
  Bulk loader for data structure metadata
  """
  require Logger

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureRelation
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Loader.FieldsAsStructures
  alias TdDd.Repo

  def load(structure_records, field_records, relation_records, audit_fields) do
    structure_count = Enum.count(structure_records)
    field_count = Enum.count(field_records)
    Logger.info("Starting bulk load (#{structure_count}SR+#{field_count}FR)")

    {fields_as_structures, fields_as_relations} =
      fields_as_structures(field_records, structure_records)

    Multi.new()
    |> Multi.run(:audit, fn _, _ -> {:ok, audit_fields} end)
    |> Multi.run(:structure_records, fn _, _ ->
      {:ok, structure_records ++ fields_as_structures}
    end)
    |> Multi.run(:field_records, fn _, _ -> {:ok, field_records} end)
    |> Multi.run(:relation_records, fn _, _ ->
      {:ok, relation_records ++ fields_as_relations}
    end)
    |> Multi.run(:structures, &upsert_structures/2)
    |> Multi.run(:versions, &get_structure_versions/2)
    |> Multi.run(:updated_versions, &update_structure_versions/2)
    |> Multi.run(:inserted_versions, &insert_structure_versions/2)
    |> Multi.run(:versions_by_external_id, &versions_by_external_id/2)
    |> Multi.run(:relations, &upsert_relations/2)
    |> Multi.run(:deleted_structures, &delete_structures/2)
    |> Repo.transaction()
  end

  defp fields_as_structures(field_records, structure_records) do
    fields_by_parent = FieldsAsStructures.group_by_parent(field_records, structure_records)
    fields_as_structures = FieldsAsStructures.as_structures(fields_by_parent)
    fields_as_relations = FieldsAsStructures.as_relations(fields_by_parent)
    {fields_as_structures, fields_as_relations}
  end

  defp upsert_structures(_repo, %{
         audit: audit_fields,
         structure_records: records
       }) do
    Logger.info("Upserting data structures (#{Enum.count(records)} records)")

    records
    |> Enum.map(&(&1 |> Map.merge(audit_fields)))
    |> Enum.map(&create_or_update_data_structure/1)
    |> errors_or_structs
  end

  defp delete_structures(_repo, %{
         versions: versions,
         inserted_versions: inserted_versions,
         audit: %{last_change_at: deleted_at}
       }) do
    deleted_versions =
      versions
      |> Enum.filter(& &1)
      |> Enum.concat(inserted_versions)
      |> Repo.preload(:data_structure)
      |> Enum.group_by(&{&1.data_structure.system_id, &1.group}, & &1.id)
      |> Enum.map(&delete_group_structures(&1, deleted_at))
      |> Enum.flat_map(fn {_count, data_structures} -> data_structures end)
      |> Repo.preload(:versions)

    {:ok, deleted_versions}
  end

  defp delete_group_structures({{system_id, group}, upserted_ids}, deleted_at) do
    Repo.update_all(
      from(dsv in DataStructureVersion,
        join: ds in assoc(dsv, :data_structure),
        where: ds.system_id == ^system_id,
        where: dsv.group == ^group,
        where: dsv.id not in ^upserted_ids,
        where: is_nil(dsv.deleted_at),
        select: ds
      ),
      set: [deleted_at: deleted_at]
    )
  end

  defp create_or_update_data_structure(attrs) do
    case fetch_data_structure(attrs) do
      nil ->
        %DataStructure{}
        |> DataStructure.changeset(attrs)
        |> Repo.insert()

      s ->
        s
        |> DataStructure.loader_changeset(attrs)
        |> Repo.update()
    end
  end

  defp fetch_data_structure(%{external_id: nil} = attrs) do
    attrs
    |> Map.drop([:external_id])
    |> fetch_data_structure
  end

  defp fetch_data_structure(%{external_id: _} = attrs) do
    Repo.get_by(DataStructure, Map.take(attrs, [:system_id, :external_id]))
  end

  defp fetch_data_structure(%{system_id: system_id, name: name, group: group}) do
    Repo.one(
      from(
        s in DataStructure,
        where:
          s.system_id == ^system_id and s.name == ^name and s.group == ^group and
            is_nil(s.external_id)
      )
    )
  end

  defp get_structure_versions(_repo, %{structures: structures, structure_records: records}) do
    Logger.info("Getting data structure versions (#{Enum.count(structures)} records)")

    versions =
      records
      |> Enum.map(&Map.get(&1, :version))
      |> Enum.zip(structures)
      |> Enum.map(&get_structure_version/1)

    {:ok, versions}
  end

  defp update_structure_versions(_repo, %{versions: versions, structure_records: records}) do
    Logger.info("Updating data structure versions (#{Enum.count(records)} records)")

    versions
    |> Enum.zip(records)
    |> Enum.reject(fn {dsv, _record} -> is_nil(dsv) end)
    |> Enum.map(&update_structure_version/1)
    |> errors_or_structs
  end

  defp update_structure_version({%DataStructureVersion{} = dsv, %{} = attrs}) do
    attrs = Map.put(attrs, :deleted_at, nil)

    dsv
    |> DataStructureVersion.update_changeset(attrs)
    |> Repo.update()
  end

  defp insert_structure_versions(_repo, %{
         versions: versions,
         structures: structures,
         structure_records: records
       }) do
    Logger.info("Inserting data structure versions (#{Enum.count(structures)} records)")

    records
    |> Enum.map(&Map.get(&1, :version))
    |> Enum.zip(structures)
    |> Enum.zip(records)
    |> Enum.zip(versions)
    |> Enum.filter(fn {{{_v, _s}, _rec}, dsv} -> is_nil(dsv) end)
    |> Enum.map(fn {{{v, s}, r}, _dsv} -> {v, s, r} end)
    |> Enum.map(&insert_new_version/1)
    |> errors_or_structs
  end

  defp insert_new_version({nil, data_structure, record}) do
    insert_new_version({0, data_structure, record})
  end

  defp insert_new_version({version, %DataStructure{id: id}, record}) do
    attrs = Map.merge(record, %{data_structure_id: id, version: version})

    %DataStructureVersion{}
    |> DataStructureVersion.changeset(attrs)
    |> Repo.insert()
  end

  defp get_structure_version({nil, data_structure}) do
    get_structure_version({0, data_structure})
  end

  defp get_structure_version({version, %DataStructure{id: id}}) do
    attrs = %{data_structure_id: id, version: version}
    Repo.get_by(DataStructureVersion, attrs)
  end

  defp get_or_create_relation(%DataStructureVersion{id: parent_id}, %DataStructureVersion{
         id: child_id
       }) do
    attrs = %{parent_id: parent_id, child_id: child_id}

    case Repo.get_by(DataStructureRelation, attrs) do
      nil ->
        %DataStructureRelation{}
        |> DataStructureRelation.changeset(attrs)
        |> Repo.insert()

      r ->
        {:ok, r}
    end
  end

  defp versions_by_external_id(_repo, %{versions: versions, inserted_versions: inserted_versions}) do
    versions_by_external_id =
      versions
      |> Enum.filter(& &1)
      |> Enum.concat(inserted_versions)
      |> Repo.preload(:data_structure)
      |> Map.new(&get_external_id/1)

    {:ok, versions_by_external_id}
  end

  defp get_external_id(%DataStructureVersion{data_structure: %{external_id: external_id}} = dsv) do
    {external_id, dsv}
  end

  defp upsert_relations(_repo, %{relation_records: []}) do
    {:ok, []}
  end

  defp upsert_relations(_repo, %{
         versions_by_external_id: versions_by_external_id,
         relation_records: relation_records
       }) do
    relation_records
    |> Enum.map(&find_parent_child(&1, versions_by_external_id))
    |> Enum.filter(fn {parent, child} -> !is_nil(parent) && !is_nil(child) end)
    |> Enum.map(fn {parent, child} -> get_or_create_relation(parent, child) end)
    |> errors_or_structs
  end

  defp find_parent_child(
         %{parent_external_id: parent_external_id, child_external_id: child_external_id},
         versions_by_external_id
       ) do
    parent = Map.get(versions_by_external_id, parent_external_id)
    child = Map.get(versions_by_external_id, child_external_id)

    {parent, child}
  end

  defp find_parent_child(_, _), do: {nil, nil}

  defp errors_or_structs(results) do
    errors = changeset_errors(results)

    case Enum.empty?(errors) do
      true -> {:ok, results |> Enum.map(fn {:ok, struct} -> struct end)}
      false -> {:error, errors}
    end
  end

  defp changeset_errors(results) do
    results
    |> Enum.with_index(1)
    |> Enum.filter(&is_error/1)
    |> Enum.map(fn {{:error, changeset}, offset} -> {changeset, offset} end)
  end

  defp is_error({{:error, _}, _}), do: true
  defp is_error({:error, _}), do: true
  defp is_error(_), do: false
end
