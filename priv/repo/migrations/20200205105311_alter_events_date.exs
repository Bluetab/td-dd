defmodule TdCx.Repo.Migrations.AlterEventsDate do
  use Ecto.Migration

  def up do
    alter table(:events) do
      modify :date, :utc_datetime_usec
    end
  end

  def down do
    alter table(:events) do
      modify :date, :utc_datetime
    end
  end
end
