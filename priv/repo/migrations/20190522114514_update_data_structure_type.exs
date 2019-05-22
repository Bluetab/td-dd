defmodule TdDd.Repo.Migrations.UpdateDataStructureType do
  use Ecto.Migration

  def up do
    update_ds_type_with_metadata_type(["Metric", "Attribute"])
  end

  def down do
    update_type_to_field(["Metric", "Attribute"])
  end

  defp update_ds_type_with_metadata_type(metadata_types) do
    metadata_types_str = metadata_types_to_str(metadata_types)
    execute("update data_structures set \"type\"=metadata->>'type' where metadata->>'type' in (#{metadata_types_str}) and \"type\" <> metadata->>'type' ;")
  end

  defp update_type_to_field(metadata_types) do
    metadata_types_str = metadata_types_to_str(metadata_types)
    execute("update data_structures set \"type\"='Field' where metadata->>'type' in (#{metadata_types_str}) and \"type\" <> 'Field' ;")
  end

  defp metadata_types_to_str(metadata_types) do
    Enum.map(metadata_types, &("'#{&1}'")) |> Enum.join(",")
  end
end
