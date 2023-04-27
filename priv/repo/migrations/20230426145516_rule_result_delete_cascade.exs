defmodule TdDd.Repo.Migrations.RuleResultDeleteCascade do
  use Ecto.Migration

  def up do
    drop constraint("rule_results", "rule_results_implementation_id_fkey")

    alter table("rule_results") do
      modify(:implementation_id, references("rule_implementations", on_delete: :delete_all))
    end
  end

  def down do
    drop constraint("rule_results", "rule_results_implementation_id_fkey")

    alter table("rule_results") do
      modify(:implementation_id, references("rule_implementations", on_delete: :nilify_all))
    end
  end
end
