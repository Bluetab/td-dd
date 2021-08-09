defmodule TdDq.Repo.Migrations.AddRuleImplementationsDatasetPopulationValidations do
  use Ecto.Migration

  def change do
    alter table("rule_implementations"), do: add(:dataset, {:array, :map}, default: [])
    alter table("rule_implementations"), do: add(:population, {:array, :map}, default: [])
    alter table("rule_implementations"), do: add(:validations, {:array, :map}, default: [])
  end
end
