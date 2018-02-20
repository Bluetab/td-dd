defmodule DataDictionary.Repo.Migrations.CreateDataFields do
  use Ecto.Migration

  def change do
    create table(:data_fields) do
      add :name, :string
      add :type, :string
      add :precision, :integer, default: 0, null: false
      add :nullable, :boolean, default: true, null: false
      add :description, :string, size: 500, null: true
      add :business_concept_id, :integer, null: true
      add :last_change, :utc_datetime
      add :modifier, :integer
      add :data_structure_id, references(:data_structures, on_delete: :nothing)

      timestamps()
    end

    create index(:data_fields, [:data_structure_id])
  end
end
