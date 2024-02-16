defmodule TdDd.Repo.Migrations.AlterRuleImplementationsTimestampPrecision do
  use Ecto.Migration

  def change do
    alter table("rule_implementations") do
      modify(:inserted_at, :utc_datetime_usec, from: :utc_datetime)
      modify(:updated_at, :utc_datetime_usec, from: :utc_datetime)
    end
  end
end
