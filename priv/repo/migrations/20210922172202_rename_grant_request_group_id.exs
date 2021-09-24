defmodule TdDd.Repo.Migrations.RenameGrantRequestGroupId do
  use Ecto.Migration

  def up do
    drop constraint("grant_requests", :grant_requests_grant_request_group_id_fkey)

    rename table("grant_requests"), :grant_request_group_id, to: :group_id

    alter table("grant_requests") do
      modify :group_id, references("grant_request_groups", on_delete: :delete_all)
    end
  end

  def down do
    drop constraint("grant_requests", :grant_requests_group_id_fkey)

    rename table("grant_requests"), :group_id, to: :grant_request_group_id

    alter table("grant_requests") do
      modify :grant_request_group_id, references("grant_request_groups", on_delete: :delete_all)
    end
  end
end
