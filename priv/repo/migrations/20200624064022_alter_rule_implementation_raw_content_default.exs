defmodule TdDq.Repo.Migrations.AlterRuleImplementationRawContentDefault do
  use Ecto.Migration

  def up do
    alter table("rule_implementations") do
      modify(:raw_content, :map, default: nil)
    end
  end

  def down do
    alter table("rule_implementations") do
      modify(:raw_content, :map, default: %{})
    end
  end
end
