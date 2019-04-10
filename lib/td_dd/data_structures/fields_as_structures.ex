defmodule TdDd.Loader.FieldsAsStructures do
  @moduledoc """
  Support for loading data fields as structures.
  """

  @structure_keys [:system_id, :group, :name, :external_id, :version]
  @liftable_metadata [:nullable, :precision, :business_concept_id]

  def group_by_parent(field_records, structure_records) do
    parents =
      structure_records
      |> Enum.group_by(&parent_key/1)
      |> Enum.into(%{}, fn {key, [h | _]} -> {key, h} end)

    field_records
    |> Enum.map(&lift_metadata/1)
    |> Enum.group_by(&parent_key/1, &Map.drop(&1, @structure_keys))
    |> Enum.into(%{}, fn {keys, recs} -> {Map.get(parents, keys), recs} end)
  end

  defp parent_key(%{external_id: nil} = map) do
    map
    |> Map.drop([:external_id])
    |> parent_key
  end

  defp parent_key(%{} = map) do
    Map.take(map, @structure_keys)
  end

  def lift_metadata(field_or_record) do
    metadata =
      field_or_record
      |> Map.take(@liftable_metadata)
      |> Enum.filter(fn {_, v} -> not is_nil(v) end)
      |> Enum.into(Map.get(field_or_record, :metadata, %{}))

    field_or_record
    |> Map.drop(@liftable_metadata)
    |> Map.put(:metadata, metadata)
  end

  def as_structures({parent, fields}) do
    fields
    |> Enum.map(&as_structure(parent, &1))
  end

  def as_structures(fields_by_parent) do
    fields_by_parent
    |> Enum.flat_map(&as_structures/1)
  end

  defp as_structure(parent, %{field_name: name} = field) do
    field
    |> Map.drop([:field_name])
    |> Map.put(:name, name)
    |> as_child_structure(parent)
  end

  defp as_child_structure(field, parent) do
    field_id = get_child_id(parent, field)

    parent
    |> Map.take([:domain_id, :group, :ou, :system_id, :version])
    |> Map.merge(field)
    |> Map.put(:class, "field")
    |> Map.put(:external_id, field_id)
  end

  def as_relations({parent, fields}) do
    fields
    |> Enum.map(&as_relation(parent, &1))
  end

  def as_relations(fields_by_parent) do
    fields_by_parent
    |> Enum.flat_map(&as_relations/1)
  end

  defp as_relation(
         %{group: group, system_id: system_id, name: parent_name} = parent,
         %{field_name: name} = field
       ) do
    field_id = get_child_id(parent, field)

    %{
      system_id: system_id,
      parent_group: group,
      parent_external_id: Map.get(parent, :external_id),
      parent_name: parent_name,
      child_group: group,
      child_external_id: field_id,
      child_name: name
    }
  end

  defp get_child_id(parent, %{field_name: name}) do
    get_parent_id(parent) <> "/" <> name
  end

  defp get_child_id(parent, %{name: name}) do
    get_parent_id(parent) <> "/" <> name
  end

  defp get_parent_id(%{name: name, external_id: nil}), do: name
  defp get_parent_id(%{external_id: external_id}), do: external_id
  defp get_parent_id(%{name: name}), do: name
end
