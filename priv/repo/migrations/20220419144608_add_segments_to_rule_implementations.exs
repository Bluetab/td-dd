defmodule TdDd.Repo.Migrations.AddsegmentsToRuleImplementations do
  use Ecto.Migration
  alias TdDq.Rules.RuleResult

  def up do
    alter table("rule_implementations") do
      add(:segments, {:array, :map}, default: [])
    end

    create table("segment_results") do
      add(:result, :decimal, scale: 2, precision: 5)
      add(:records, :bigint)
      add(:errors, :bigint)
      add(:params, :map)
      add(:details, :map)
      add(:rule_result_id, references("rule_results", on_delete: :delete_all))

      timestamps()
    end
  end

  def down do
    drop table("segment_results")
    alter table("rule_implementations"), do: remove(:segments)
  end
end
