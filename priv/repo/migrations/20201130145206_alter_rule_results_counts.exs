defmodule TdDq.Repo.Migrations.AlterRuleResultsCounts do
  use Ecto.Migration

  def change do
    alter table("rule_results") do
      modify(:errors, :bigint, from: :integer)
      modify(:records, :bigint, from: :integer)
    end
  end
end
