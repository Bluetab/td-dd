defmodule TdDd.Repo.Migrations.AddMutableMetadata do
  use Ecto.Migration

  def up do
    create table(:mutable_metadata) do
      add :fields, :map, null: false
      add :version, :integer, null: false, default: 0
      add :data_structure_id, references(:data_structures, on_delete: :delete_all), null: false

      timestamps()
    end
  end

  def down do
    drop table(:mutable_metadata)
  end
end
