defmodule TdDd.Repo.Migrations.AddMetadataFieldsDataStructureType do
  use Ecto.Migration

  def up do
    alter table(:data_structure_types) do
      add(:metadata_fields, :map)
    end
  end

  def down do
    alter table(:data_structure_types) do
      remove(:metadata_fields)
    end
  end
end
