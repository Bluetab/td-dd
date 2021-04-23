defmodule TdDq.Repo.Migrations.AddResultTypeToRuleResult do
  use Ecto.Migration

  def change do
    alter table("rule_results") do
      add(:result_type, :string)
    end

    execute("""
      update rule_results rr
      set result_type = r.result_type
      from rule_implementations ri, rules r
      where rr.implementation_key = ri.implementation_key and ri.rule_id = r.id
    """, "")
  end
end
