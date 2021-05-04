defmodule TdDq.Repo.Migrations.CreateQualityRuleType do
  use Ecto.Migration

  def change do
    create table(:quality_rule_types) do
      add(:name, :string)
      add(:params, :map)

      timestamps()
    end
  end
end
