defmodule TdDq.Repo.Migrations.PartialIndexNameBcId do
  use Ecto.Migration

  def change do
    drop(unique_index(:rules, [:business_concept_id, :name]))
    
    create unique_index(:rules, [:business_concept_id, :name], where: "business_concept_id IS NOT NULL")
    create unique_index(:rules, [:name], where: "business_concept_id IS NULL")
  end
end
