defmodule TdDd.Repo.Migrations.CreateMetadataFields do
  use Ecto.Migration

  def change do
    create table("metadata_fields") do
      add :data_structure_type_id, references("data_structure_types", on_delete: :nothing)
      add :name, :string
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index("metadata_fields", [:data_structure_type_id, :name])
  end
end
