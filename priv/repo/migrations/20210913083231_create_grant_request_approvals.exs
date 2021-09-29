defmodule TdDd.Repo.Migrations.CreateGrantRequestApprovals do
  use Ecto.Migration

  def change do
    create table("grant_request_approvals") do
      add :grant_request_id, references("grant_requests", on_delete: :delete_all), null: false
      add :user_id, :integer, null: false
      add :domain_id, :integer, null: false
      add :role, :string, null: false
      add :is_rejection, :boolean, null: false, default: false
      add :comment, :string

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index("grant_request_approvals", [:grant_request_id, :role])
  end
end
