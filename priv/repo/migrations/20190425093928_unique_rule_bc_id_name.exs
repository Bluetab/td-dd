defmodule TdDq.Repo.Migrations.UniqueRuleBcIdName do
  use Ecto.Migration

  def change do
     create unique_index(:rules, [:business_concept_id, :name])
  end
end
