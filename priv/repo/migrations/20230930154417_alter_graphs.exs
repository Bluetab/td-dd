defmodule TdDd.Repo.Migrations.AlterGraphs do
  use Ecto.Migration

  def up do
    alter table("graphs") do
      modify :inserted_at, :utc_datetime_usec
      modify :updated_at, :utc_datetime_usec
      add(:params, :map)
    end
  end

  def down do
    alter table("graphs") do
      modify :inserted_at, :utc_datetime
      modify :updated_at, :utc_datetime
      remove(:params, :map)
    end
  end
end
