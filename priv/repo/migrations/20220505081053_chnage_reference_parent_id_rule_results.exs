defmodule TdDd.Repo.Migrations.ChnageReferenceParentIdRuleResults do
  use Ecto.Migration


  def up do
    alter table("rule_results"), do: remove(:parent_id)
    alter table("rule_results") do
      add(:parent_id, references("rule_results", on_delete: :delete_all))
    end
  end

  def down do
    alter table("rule_results"), do: remove(:parent_id)
    alter table("rule_results") do
      add(:parent_id, references("rule_results", on_delete: :delete_all))
    end
  end


end
