defmodule TdDd.Repo.Migrations.AddCreatedByToGrantRequestGroup do
  use Ecto.Migration

  def up do
    alter table("grant_request_groups") do
      add :created_by_id, :integer
    end

    execute("update grant_request_groups set created_by_id = user_id")

    alter table("grant_request_groups") do
      modify :created_by_id, :integer, null: false
    end
  end

  def down do
    alter table("grant_request_groups") do
      remove :created_by_id
    end
  end
end
