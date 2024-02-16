defmodule TdDd.Repo.Migrations.AddModificationGrantToRequestGroup do
  use Ecto.Migration

  def change do
    alter table("grant_request_groups") do
      add :modification_grant_id, references("grants")
    end
  end
end
