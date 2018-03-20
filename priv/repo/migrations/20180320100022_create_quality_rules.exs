defmodule TdDq.Repo.Migrations.CreateQualityRules do
  use Ecto.Migration

  def change do
    create table(:quality_rules) do
      add :name, :string
      add :description, :string, null: true, size: 500
      add :system, :string
      add :parameters, :map
      add :type, :string
      add :quality_control_id, references(:quality_controls, on_delete: :nothing)

      timestamps()
    end

    create index(:quality_rules, [:quality_control_id])
  end
end
