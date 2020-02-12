defmodule TdCx.Repo.Migrations.ChangeDateType do
  use Ecto.Migration

  def change do
    alter table(:events) do
      modify(:date, :utc_datetime_usec)
    end
  end
end
