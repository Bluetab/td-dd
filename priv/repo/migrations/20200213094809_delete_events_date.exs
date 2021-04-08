defmodule TdCx.Repo.Migrations.DeleteEventsDate do
  use Ecto.Migration

  def change do
    alter table(:events) do
      remove :date
    end
  end
end
