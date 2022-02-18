defmodule TdDd.Repo.Migrations.AlterRuleImplementationsTimestamps do
  use Ecto.Migration

  use Ecto.Migration

  def change do
    alter table("rule_implementations") do
      modify(:inserted_at, :utc_datetime)
      modify(:updated_at, :utc_datetime)
    end
  end
end
