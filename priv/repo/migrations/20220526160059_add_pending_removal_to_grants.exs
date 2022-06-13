defmodule TdDd.Repo.Migrations.AddPendingRemovalToGrants do
  use Ecto.Migration

  def change do
    alter table("grants") do
      add :pending_removal, :boolean, null: false, default: false
    end
  end
end
