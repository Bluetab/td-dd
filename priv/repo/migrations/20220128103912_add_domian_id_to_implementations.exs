defmodule TdDd.Repo.Migrations.AddDomianIdToImplementations do
  use Ecto.Migration

  def change do
    alter table("rule_implementations") do
      add(:domain_id, :bigint, null: true)
    end

    execute(
      "update rule_implementations set domain_id = (select domain_id from rules as r where r.id = rule_id)",
      ""
    )
  end
end
