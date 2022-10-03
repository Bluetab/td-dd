defmodule TdDd.Repo.Migrations.AddUserIdToGrantRequestStatus do
  use Ecto.Migration

  def change do
    alter table("grant_request_status") do
      add :user_id, :integer, null: false, default: 0
    end
  end
end
