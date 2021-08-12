defmodule TdDd.Repo.Migrations.AlterGrantsDateRange do
  use Ecto.Migration

  def change do
    alter table("grants") do
      modify(:start_date, :date, from: :utc_datetime_usec)
      modify(:end_date, :date, from: :utc_datetime_usec)
    end
  end
end
