defmodule TdCx.Repo.Migrations.UpdateTimestamps do
  use Ecto.Migration

  def change do
    alter table(:events) do
      remove :updated_at
      modify :inserted_at, :utc_datetime_usec
    end
  end
end
