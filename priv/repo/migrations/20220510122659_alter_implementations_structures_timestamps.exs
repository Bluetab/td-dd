defmodule TdDd.Repo.Migrations.AlterImplementationsStructuresTimestamps do
  use Ecto.Migration

  def change do
    alter table("implementations_structures") do
      modify(:inserted_at, :utc_datetime_usec, from: :utc_datetime)
      modify(:updated_at, :utc_datetime_usec, from: :utc_datetime)
    end
  end
end
