defmodule TdDd.Repo.Migrations.UpdateDataStructureType do
  use Ecto.Migration

  def up do
    update_ds_type_with_metadata_type(["Metric", "Attribute"])
  end

  def down do
  end

  defp update_ds_type_with_metadata_type(metadata_types) do
    metadata_types_str = Enum.map(metadata_types, &"'#{&1}'") |> Enum.join(",")

    execute(
      "update data_structures set \"type\"=metadata->>'type' where metadata->>'type' in (#{metadata_types_str}) and \"type\" <> metadata->>'type' ;"
    )
  end
end
