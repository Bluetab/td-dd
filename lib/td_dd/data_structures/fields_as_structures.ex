defmodule TdDd.Loader.FieldsAsStructures do
  @moduledoc """
  Support for loading data fields as structures.
  """

  @structure_keys [:system_id, :group, :name, :external_id]
  @liftable_metadata [:nullable, :precision, :type]
  @table_types ["tabl", "view"]
  @white_list_types ["Attribute", "Metric"]

  def group_by_parent(field_records, structure_records) do
    parents =
      structure_records
      |> Enum.group_by(& &1.external_id)
      |> Enum.into(%{}, fn {key, [h | _]} -> {key, h} end)

    field_records
    |> Enum.map(&lift_metadata/1)
    |> Enum.group_by(& &1.external_id, &Map.drop(&1, @structure_keys))
    |> Enum.into(%{}, fn {keys, recs} -> {Map.get(parents, keys), recs} end)
  end

  def lift_metadata(field_or_record) do
    metadata =
      field_or_record
      |> Map.take(@liftable_metadata)
      |> Enum.filter(fn {_, v} -> not is_nil(v) end)
      |> Enum.into(Map.get(field_or_record, :metadata, %{}), fn {k, v} -> {to_string(k), v} end)

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
    |> Map.delete(:field_name)
    |> Map.put(:name, name)
    |> as_child_structure(parent)
  end

  defp as_child_structure(field, parent) do
    field_id = get_child_id(parent, field)
    type = child_type(parent, field)

    parent
    |> Map.take([:domain_id, :group, :ou, :system_id])
    |> Map.merge(field)
    |> Map.put(:class, "field")
    |> Map.put(:type, type)
    |> Map.put(:external_id, field_id)
  end

  def as_relations({parent, fields}) do
    fields |> Enum.map(&as_relation(parent, &1))
  end

  def as_relations(fields_by_parent) do
    fields_by_parent |> Enum.flat_map(&as_relations/1)
  end

  defp as_relation(%{external_id: external_id} = parent, field) do
    field_id = get_child_id(parent, field)
    %{parent_external_id: external_id, child_external_id: field_id}
  end

  def child_type(%{} = parent, %{} = child) do
    parent_type = parent |> Map.get(:type) |> String.downcase()
    child_type = child |> Map.get(:metadata, %{}) |> Map.get("type", "Column")

    case Enum.any?(@white_list_types, &(&1 == child_type)) do
      true -> child_type
      false -> child_type_from_parent(parent_type)
    end
  end

  defp child_type_from_parent(parent_type) do
    case Enum.any?(@table_types, &String.contains?(parent_type, &1)) do
      true -> "Column"
      false -> "Field"
    end
  end

  defp get_child_id(%{external_id: external_id}, %{field_name: name}) do
    external_id <> "/" <> name
  end

  defp get_child_id(%{external_id: external_id}, %{name: name}) do
    external_id <> "/" <> name
  end
end
