defmodule TdDd.Repo.Migrations.DropPendingRemovalToGrants do
  use Ecto.Migration

  def change do
    alter table("grants") do
      remove :pending_removal
    end
  end
end
