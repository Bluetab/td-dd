defmodule TdDq.Repo.Migrations.AddUniqueQualityRuleTypeName do
  use Ecto.Migration

  def change do
    create unique_index(:quality_rule_types, [:name])
  end
end
