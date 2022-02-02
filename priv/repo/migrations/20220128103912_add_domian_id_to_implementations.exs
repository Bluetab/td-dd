defmodule TdDd.Repo.Migrations.AddDomianIdToImplementations do
  use Ecto.Migration

  def up do
    alter(table("rule_implementations"), do: add(:domain_id, :bigint, null: true))

    execute(
      "update rule_implementations set domain_id = (select domain_id from rules as r where r.id = rule_id)"
    )
  end

  def down do
    alter(table("rule_implementations"), do: remove(:domain_id))
    alter(table("rules"), do: modify(:domain_id, :bigint, null: true))
  end
end
