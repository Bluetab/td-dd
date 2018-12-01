defmodule TdDd.Loader do
  @moduledoc """
  Bulk loader for data structure metadata
  """
  require Logger

  alias Ecto.Adapters.SQL
  alias Ecto.Multi
  alias TdDd.DataStructures.DataField
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureRelation
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Repo

  def load(structure_records, field_records, relation_records, audit_fields) do
    Logger.info(
      "Starting bulk load process (#{Enum.count(structure_records)}SR+#{Enum.count(field_records)}FR)"
    )

    multi =
      Multi.new()
      |> Multi.run(:audit, fn _ -> {:ok, audit_fields} end)
      |> Multi.run(:structure_records, fn _ -> {:ok, structure_records} end)
      |> Multi.run(:field_records, fn _ -> {:ok, field_records} end)
      |> Multi.run(:relation_records, fn _ -> {:ok, relation_records} end)
      |> Multi.run(:structures, &upsert_structures/1)
      |> Multi.run(:versions, &upsert_structure_versions/1)
      |> Multi.run(:versions_by_key, &versions_by_key/1)
      |> Multi.run(:relations, &upsert_relations/1)
      |> Multi.run(:diffs, &diff_structures/1)
      |> Multi.run(:removed, &remove_fields/1)
      |> Multi.run(:added, &insert_fields/1)
      |> Multi.run(:modified, &update_fields/1)
      |> Repo.transaction()

    case multi do
      {:ok, context} ->
        %{added: added, removed: removed, modified: modified} = context
        Logger.info("Bulk load process completed (-#{removed}F +#{added}F ~#{modified}F)")
        {:ok, context}

      {:error, failed_operation, failed_value, changes_so_far} ->
        Logger.warn("Bulk load process failed (operation #{failed_operation})")
        {:error, failed_operation, failed_value, changes_so_far}
    end
  end

  defp update_fields(%{diffs: diffs, audit: audit}) do
    to_update = Enum.flat_map(diffs, &Map.get(&1, :modify))
    Logger.info("Updating existing fields (#{Enum.count(to_update)} fields)")

    to_update
    |> Enum.map(&update_field(&1, audit))
    |> errors_or_count
  end

  defp update_field({field, %{field_name: name} = attrs}, audit) do
    attrs = attrs |> Map.merge(audit)
    field |> DataField.update_changeset(attrs |> Map.merge(%{name: name})) |> Repo.update()
  end

  defp insert_fields(%{diffs: diffs, audit: audit}) do
    to_insert = Enum.flat_map(diffs, &Map.get(&1, :add))
    Logger.info("Inserting new fields (#{Enum.count(to_insert)} fields)")

    version_fields =
      to_insert
      |> Enum.map(fn {version, attrs} -> {version, insert_field(attrs, audit)} end)

    Logger.info("Inserting new field associationss (#{Enum.count(version_fields)} fields)")

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

  defp remove_fields(%{diffs: diffs}) do
    to_remove = Enum.flat_map(diffs, &Map.get(&1, :remove))

    Logger.info("Removing field associations (#{Enum.count(to_remove)} fields)")

    rows =
      to_remove
      |> Enum.map(&remove_field/1)
      |> Enum.sum()

    {:ok, rows}
  end

  defp remove_field(%{data_field_id: field_id, data_structure_version_id: version_id}) do
    q = "DELETE FROM versions_fields WHERE data_field_id = $1 and data_structure_version_id = $2"

    {:ok, %{num_rows: num_rows}} =
      SQL.query(
        Repo,
        q,
        [field_id, version_id]
      )

    num_rows
  end

  defp upsert_structures(%{audit: audit_fields, structure_records: records}) do
    Logger.info("Upserting data structures (#{Enum.count(records)} records)")

    records
    |> Enum.map(&(&1 |> Map.merge(audit_fields)))
    |> Enum.map(&create_or_update_data_structure/1)
    |> errors_or_structs
  end

  defp create_or_update_data_structure(attrs) do
    case Repo.get_by(DataStructure, Map.take(attrs, [:system, :name, :group])) do
      nil ->
        %DataStructure{}
        |> DataStructure.changeset(attrs)
        |> Repo.insert()

      s ->
        s |> DataStructure.update_changeset(attrs) |> Repo.update()
    end
  end

  defp upsert_structure_versions(%{structures: structures}) do
    Logger.info("Upserting data structure versions (#{Enum.count(structures)} records)")

    structures
    |> Enum.map(&get_or_create_version/1)
    |> errors_or_structs
  end

  defp get_or_create_version(%DataStructure{id: id}) do
    attrs = %{data_structure_id: id, version: 0}

    case Repo.get_by(DataStructureVersion, attrs) do
      nil ->
        %DataStructureVersion{}
        |> DataStructureVersion.changeset(attrs)
        |> Repo.insert()

      s ->
        # TODO: Get latest version
        s |> DataStructureVersion.update_changeset(attrs) |> Repo.update()
    end
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
        r
    end
  end

  defp versions_by_key(%{versions: versions}) do
    versions_by_key =
      versions
      |> Repo.preload(:data_structure)
      |> Enum.group_by(
        &{&1.data_structure.system, &1.data_structure.group, &1.data_structure.name}
      )
      |> Enum.into(%{}, fn {k, [v | _t]} -> {k, v} end)

    {:ok, versions_by_key}
  end

  defp upsert_relations(%{relation_records: []}) do
    {:ok, []}
  end

  defp upsert_relations(%{versions_by_key: versions_by_key, relation_records: relation_records}) do
    relation_records
    |> Enum.map(&find_parent_child(versions_by_key, &1))
    |> Enum.filter(fn {parent, child} -> !is_nil(parent) && !is_nil(child) end)
    |> Enum.map(fn {parent, child} -> get_or_create_relation(parent, child) end)
    |> errors_or_structs
  end

  defp find_parent_child(versions_by_key, %{
         system: system,
         parent_group: parent_group,
         parent_name: parent_name,
         child_group: child_group,
         child_name: child_name
       }) do
    parent = Map.get(versions_by_key, {system, parent_group, parent_name})
    child = Map.get(versions_by_key, {system, child_group, child_name})
    {parent, child}
  end

  defp diff_structures(%{
         versions_by_key: versions_by_key,
         field_records: records,
         audit: audit_fields
       }) do
    Logger.info(
      "Calculating differences (#{Enum.count(versions_by_key)} versions, #{Enum.count(records)} records)"
    )

    diffs =
      records
      |> Enum.map(&(&1 |> Map.merge(audit_fields)))
      |> Enum.group_by(&{&1.system, &1.group, &1.name})
      |> Map.to_list()
      |> Enum.map(fn {sysgroupname, records} ->
        {Map.get(versions_by_key, sysgroupname), records}
      end)
      |> Enum.map(fn {version, records} -> structure_diff(version, records) end)

    {:ok, diffs}
  end

  defp structure_diff(version, records) do
    field_names =
      records
      |> Enum.map(& &1.field_name)

    data_fields =
      version
      |> Repo.preload(:data_fields)
      |> Map.get(:data_fields)

    to_upsert =
      records
      |> Enum.map(fn record -> find_field(data_fields, record) end)
      |> Enum.zip(records)

    {to_insert, to_modify} =
      to_upsert
      |> Enum.split_with(fn {field, _} -> is_nil(field) end)

    to_insert =
      to_insert
      |> Enum.map(fn {_, record} -> {version, record} end)

    to_modify =
      to_modify
      |> Enum.filter(fn {field, record} -> has_changes(field, record) end)

    to_remove =
      data_fields
      |> Enum.filter(fn %{name: name} -> !Enum.any?(field_names, &(&1 == name)) end)
      |> Enum.map(fn %{id: id} -> %{data_structure_version_id: version.id, data_field_id: id} end)

    %{add: to_insert, modify: to_modify, remove: to_remove}
  end

  defp has_changes(field, record) do
    check_props = [:business_concept_id, :description, :nullable, :precision, :type, :metadata]

    defaults =
      check_props
      |> Enum.map(fn p -> {p, nil} end)
      |> Enum.concat([{:metadata, %{}}])
      |> Map.new()

    field |> Map.take(check_props) != defaults |> Map.merge(record) |> Map.take(check_props)
  end

  defp find_field(data_fields, %{field_name: field_name}) do
    data_fields
    |> Enum.find(fn %{name: name} -> name == field_name end)
  end

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
