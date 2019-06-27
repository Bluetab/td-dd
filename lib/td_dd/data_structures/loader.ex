defmodule TdDd.Loader do
  @moduledoc """
  Bulk loader for data structure metadata
  """
  require Logger

  import Ecto.Query, warn: false

  alias Ecto.Adapters.SQL
  alias Ecto.Multi
  alias TdDd.DataStructures.DataField
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
    |> Multi.run(:inserted_versions, &insert_structure_versions/2)
    # |> Multi.run(:versions, &upsert_structure_versions/2)
    |> Multi.run(:versions_by_sys_group_name_version, &versions_by_sys_group_name_version/2)
    |> Multi.run(:relations, &upsert_relations/2)
    |> Multi.run(:diffs, &diff_structures/2)
    |> Multi.run(:removed, &remove_fields/2)
    |> Multi.run(:kept, &keep_fields/2)
    |> Multi.run(:added, &insert_fields/2)
    |> Multi.run(:modified, &update_fields/2)
    |> Repo.transaction()
  end

  defp fields_as_structures(field_records, structure_records) do
    fields_by_parent = FieldsAsStructures.group_by_parent(field_records, structure_records)
    fields_as_structures = FieldsAsStructures.as_structures(fields_by_parent)
    fields_as_relations = FieldsAsStructures.as_relations(fields_by_parent)
    {fields_as_structures, fields_as_relations}
  end

  defp update_fields(_repo, %{diffs: diffs, audit: audit}) do
    to_update = Enum.flat_map(diffs, &Map.get(&1, :modify))
    Logger.info("Updating existing fields (#{Enum.count(to_update)} fields)")

    to_update
    |> Enum.map(&update_field(&1, audit))
    |> errors_or_count
  end

  defp update_field({field, attrs}, audit) do
    modifiable_fields = [:description]
    attrs = attrs |> Map.take(modifiable_fields) |> Map.merge(audit)
    field |> DataField.loader_changeset(attrs) |> Repo.update()
  end

  defp insert_fields(_repo, %{diffs: diffs, audit: audit}) do
    to_insert = Enum.flat_map(diffs, &Map.get(&1, :add))
    Logger.info("Inserting new fields (#{Enum.count(to_insert)} fields)")

    version_fields =
      to_insert
      |> Enum.map(fn {version, attrs} -> {version, insert_field(attrs, audit)} end)

    Logger.info("Inserting new field associations (#{Enum.count(version_fields)} fields)")

    entries =
      version_fields
      |> Enum.map(fn {version, field} ->
        %{data_field_id: field.id, data_structure_version_id: version.id}
      end)

    {count, _} = Repo.insert_all("versions_fields", entries)

    {:ok, count}
  end

  defp insert_field(%{field_name: name} = attrs, audit) do
    %DataField{}
    |> DataField.changeset(attrs |> Map.merge(%{name: name}) |> Map.merge(audit))
    |> Repo.insert!()
  end

  defp keep_fields(_repo, %{diffs: diffs}) do
    to_keep = Enum.flat_map(diffs, &Map.get(&1, :keep))

    Logger.info("Keeping field associations (#{Enum.count(to_keep)} fields)")

    entries =
      to_keep
      |> Enum.map(fn {version, field} ->
        %{data_field_id: field.id, data_structure_version_id: version.id}
      end)

    {count, _} = Repo.insert_all("versions_fields", entries)

    {:ok, count}
  end

  defp remove_fields(_repo, %{diffs: diffs}) do
    to_remove = Enum.flat_map(diffs, &Map.get(&1, :remove))

    Logger.info("Removing field associations (#{Enum.count(to_remove)} fields)")

    rows =
      to_remove
      |> Enum.map(&remove_field/1)
      |> Enum.sum()

    {:ok, rows}
  end

  defp remove_field({%DataStructureVersion{id: version_id}, %DataField{id: field_id}}) do
    remove_field(version_id, field_id)
  end

  defp remove_field(%{data_field_id: field_id, data_structure_version_id: version_id}) do
    remove_field(version_id, field_id)
  end

  defp remove_field(version_id, field_id) do
    q = "DELETE FROM versions_fields WHERE data_field_id = $1 and data_structure_version_id = $2"

    {:ok, %{num_rows: num_rows}} = SQL.query(Repo, q, [field_id, version_id])

    num_rows
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

  defp insert_structure_versions(_repo, %{
         versions: versions,
         structures: structures,
         structure_records: records
       }) do
    Logger.info("Inserting data structure versions (#{Enum.count(structures)} records)")

    records
    |> Enum.map(&Map.get(&1, :version))
    |> Enum.zip(structures)
    |> Enum.zip(versions)
    |> Enum.filter(fn {{_v, _s}, dsv} -> is_nil(dsv) end)
    |> Enum.map(fn {{v, s}, _dsv} -> {v, s} end)
    |> Enum.map(&insert_new_version/1)
    |> errors_or_structs
  end

  defp insert_new_version({nil, data_structure}) do
    insert_new_version({0, data_structure})
    # TODO: Should create new version if structure has changed
  end

  defp insert_new_version({version, %DataStructure{id: id}}) do
    attrs = %{data_structure_id: id, version: version}

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

  defp versions_by_sys_group_name_version(_repo, %{
         versions: versions,
         inserted_versions: inserted_versions
       }) do
    versions_by_sys_group_name_version =
      versions
      |> Enum.filter(& &1)
      |> Enum.concat(inserted_versions)
      |> Repo.preload([:data_structure])
      |> Map.new(&key_value/1)

    {:ok, versions_by_sys_group_name_version}
  end

  defp key_value(%DataStructureVersion{data_structure: data_structure, version: version} = dsv) do
    map =
      data_structure
      |> Map.take([:system_id, :group, :name, :external_id])
      |> Map.put(:version, version)

    key =
      [:system_id, :group, :name, :external_id, :version]
      |> Enum.map(&Map.get(map, &1))
      |> List.to_tuple()

    {key, dsv}
  end

  defp upsert_relations(_repo, %{relation_records: []}) do
    {:ok, []}
  end

  defp upsert_relations(_repo, %{
         versions_by_sys_group_name_version: versions_by_sys_group_name_version,
         relation_records: relation_records
       }) do
    relation_records
    |> Enum.map(&find_parent_child(&1, versions_by_sys_group_name_version))
    |> Enum.filter(fn {parent, child} -> !is_nil(parent) && !is_nil(child) end)
    |> Enum.map(fn {parent, child} -> get_or_create_relation(parent, child) end)
    |> errors_or_structs
  end

  defp find_parent_child(
         %{
           system_id: system_id,
           parent_group: parent_group,
           parent_name: parent_name,
           child_group: child_group,
           child_name: child_name
         } = relation,
         versions_by_sys_group_name_version
       ) do
    parent_external_id = Map.get(relation, :parent_external_id)
    child_external_id = Map.get(relation, :child_external_id)
    version = Map.get(relation, :version, 0)

    parent =
      Map.get(
        versions_by_sys_group_name_version,
        {system_id, parent_group, parent_name, parent_external_id, version}
      )

    child =
      Map.get(
        versions_by_sys_group_name_version,
        {system_id, child_group, child_name, child_external_id, version}
      )

    {parent, child}
  end

  defp find_parent_child(_, _), do: {nil, nil}

  defp diff_structures(_repo, %{
         versions_by_sys_group_name_version: versions_by_sys_group_name_version,
         inserted_versions: inserted_versions,
         field_records: records,
         audit: audit_fields
       }) do
    Logger.info(
      "Calculating differences (#{Enum.count(versions_by_sys_group_name_version)} versions, #{
        Enum.count(records)
      } records)"
    )

    inserted_version_ids = inserted_versions |> Enum.map(& &1.id)

    diffs =
      records
      |> Enum.map(&(&1 |> Map.merge(audit_fields)))
      |> Enum.group_by(&{&1.system_id, &1.group, &1.name, &1.external_id, &1.version})
      |> Map.to_list()
      |> Enum.map(fn {sys_group_name_version, records} ->
        {Map.get(versions_by_sys_group_name_version, sys_group_name_version), records}
      end)
      |> Enum.map(fn {version, records} ->
        structure_diff(version, records, Enum.member?(inserted_version_ids, version.id))
      end)

    {:ok, diffs}
  end

  defp structure_diff(version, records, is_new_version) do
    data_fields =
      version
      |> Ecto.assoc([:data_structure, :versions, :data_fields])
      |> Repo.all()

    to_upsert =
      records
      |> Enum.map(fn record -> find_field(data_fields, record) end)
      |> Enum.zip(records)

    {to_insert, to_keep} =
      to_upsert
      |> Enum.split_with(fn {field, _} -> is_nil(field) end)

    to_insert =
      to_insert
      |> Enum.map(fn {_, record} -> {version, record} end)

    to_remove =
      data_fields
      |> MapSet.new()
      |> MapSet.difference(
        to_keep
        |> Enum.map(fn {field, _} -> field end)
        |> MapSet.new()
      )
      |> Enum.map(fn field -> {version, field} end)

    to_modify =
      to_keep
      |> Enum.filter(fn {field, record} -> has_changes?(field, record) end)

    to_keep =
      if is_new_version do
        to_keep |> Enum.map(fn {field, _} -> {version, field} end)
      else
        []
      end

    %{add: to_insert, modify: to_modify, remove: to_remove, keep: to_keep}
  end

  defp has_changes?(field, %{} = record) do
    check_props =
      case Map.get(record, :description) do
        nil -> [:metadata]
        _ -> [:description, :metadata]
      end

    defaults =
      check_props
      |> Enum.map(fn p -> {p, nil} end)
      |> Enum.concat([{:metadata, %{}}])
      |> Map.new()

    field |> Map.take(check_props) != defaults |> Map.merge(record) |> Map.take(check_props)
  end

  defp find_field(
         data_fields,
         %{
           field_name: name,
           type: type
         } = attrs
       ) do
    nullable = Map.get(attrs, :nullable)
    precision = Map.get(attrs, :precision)
    match = %{name: name, type: type, nullable: nullable, precision: precision}

    data_fields
    |> Enum.find(&Map.equal?(match, Map.take(&1, [:name, :type, :nullable, :precision])))
  end

  defp find_field(_data_fields, _), do: nil

  defp errors_or_structs(results) do
    errors = changeset_errors(results)

    case Enum.empty?(errors) do
      true -> {:ok, results |> Enum.map(fn {:ok, structure} -> structure end)}
      false -> {:error, errors}
    end
  end

  defp errors_or_count(results) do
    errors = changeset_errors(results)

    case Enum.empty?(errors) do
      true -> {:ok, results |> Enum.count()}
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
