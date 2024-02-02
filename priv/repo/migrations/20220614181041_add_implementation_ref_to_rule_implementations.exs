defmodule TdDd.Repo.Migrations.AddImplementationRefToRuleImplementations do
  use Ecto.Migration

  @set_implementation_ref """
  update rule_implementations riu set implementation_ref = subquery.implementation_ref
  from
    (select ri.id, fri.id as implementation_ref from rule_implementations ri
      inner join
      (
        select ri2.id, ri2.implementation_key, ri2.version from rule_implementations ri2 where (implementation_key, version)
        in (select implementation_key, min(version) from rule_implementations group by implementation_key)
      ) as fri
      on fri.implementation_key = ri.implementation_key
    ) as subquery
  where riu.id = subquery.id
  """

  def change do
    alter table("rule_implementations") do
      add(:implementation_ref, references("rule_implementations", on_delete: :delete_all),
        null: true
      )
    end
    execute(@set_implementation_ref, "")
  end
end
