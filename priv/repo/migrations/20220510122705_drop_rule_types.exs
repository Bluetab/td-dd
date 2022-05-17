defmodule TdDd.Repo.Migrations.DropRuleTypes do
  use Ecto.Migration

  def up do
    alter table("rules") do
      remove(:rule_type_id, references("rule_types"))
    end

    drop table("rule_types")
  end

  def down do
    drop_if_exists table("rule_types")

    create table("rule_types") do
      add(:name, :string)
      add(:params, :map)

      timestamps()
    end

    create unique_index("rule_types", [:name])

    alter table("rules") do
      add(:rule_type_id, references("rule_types"), null: true)
    end
  end
end
