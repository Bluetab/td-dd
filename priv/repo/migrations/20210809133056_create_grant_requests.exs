defmodule TdDd.Repo.Migrations.CreateGrantRequests do
  use Ecto.Migration

  def change do
    create table("grant_requests") do
      add :filters, :map
      add :metadata, :map

      add :grant_request_group_id, references("grant_request_groups", on_delete: :delete_all),
        null: false

      add :data_structure_id, references("data_structures", on_delete: :nothing), null: false

      timestamps(type: :utc_datetime_usec)
    end
  end
end
