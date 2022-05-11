defmodule TdDd.Repo.Migrations.ChangeReferenceParentIdRuleResults do
  use Ecto.Migration

  def change do
    alter table("rule_results") do
      modify(:parent_id, references("rule_results", on_delete: :delete_all),
        from: references("rule_results", on_delete: :delete_all)
      )
    end
  end
end
