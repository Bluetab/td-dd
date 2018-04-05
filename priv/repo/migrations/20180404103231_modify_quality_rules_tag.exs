defmodule TdDq.Repo.Migrations.ModifyQualityRulesTag do
  use Ecto.Migration

  def change do
    alter table(:quality_rules) do
      remove :tag
      add :tag, :map, null: true
    end
  end
end
