defmodule TdDd.Repo.Migrations.CreateGrantRequestStatus do
  use Ecto.Migration

  def change do
    create table("grant_request_status") do
      add :status, :string, null: false
      add :grant_request_id, references("grant_requests", on_delete: :delete_all)
      timestamps(updated_at: false, type: :utc_datetime_usec)
    end
  end
end
