defmodule TdDq.Repo.Migrations.QualityRuleImplementsQualityRuleType do
  use Ecto.Migration

  def change do
    alter table(:quality_rules) do
      add(:quality_rule_type_id, references(:quality_rule_types))
    end
  end
end
