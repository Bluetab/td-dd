defmodule TdDd.Repo.Migrations.CreateDataFields do
  use Ecto.Migration

  def change do
    create table("data_fields") do
      add :name, :string
      add :type, :string, default: nil, null: true
      add :precision, :string, default: nil, null: true
      add :nullable, :boolean, default: nil, null: true
      add :description, :text, default: nil, null: true
      add :business_concept_id, :string, default: nil, null: true
      add :last_change_at, :utc_datetime
      add :last_change_by, :integer
      add :data_structure_id, references("data_structures", on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index("data_fields", [:data_structure_id])
  end
end
