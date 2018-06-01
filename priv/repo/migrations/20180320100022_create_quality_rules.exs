defmodule TdDq.Repo.Migrations.CreateQualityRules do
  use Ecto.Migration

  def change do
    create table(:quality_rules) do
      add :name, :string
      add :description, :string, null: true, size: 500
      add :type, :string
      add :system, :string
      add :system_params, :map
      add :quality_control_id, references(:quality_controls, on_delete: :nothing)

      timestamps()
    end

    create index(:quality_rules, [:quality_control_id])
  end
end
