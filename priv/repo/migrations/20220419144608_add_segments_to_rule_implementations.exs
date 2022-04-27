defmodule TdDd.Repo.Migrations.AddsegmentsToRuleImplementations do
  use Ecto.Migration
  alias TdDq.Rules.RuleResult

  def up do
    alter table("rule_implementations") do
      add(:segments, {:array, :map}, default: [])
    end

    alter table("rule_results") do
      add(:parent_id, references("rule_results"), on_delete: :delete_all)
    end
  end

  def down do
    alter table("rule_results"), do: remove(:parent_id)
    alter table("rule_implementations"), do: remove(:segments)
  end
end
