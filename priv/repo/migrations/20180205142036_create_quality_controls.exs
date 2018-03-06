defmodule TdDQ.Repo.Migrations.CreateQualityControls do
  use Ecto.Migration

  def change do
    create table(:quality_controls) do
      add :type, :string
      add :business_concept_id, :string
      add :name, :string
      add :description, :string
      add :weight, :integer
      add :priority, :string
      add :population, :string
      add :goal, :integer
      add :minimum, :integer

      timestamps()
    end

  end
end
