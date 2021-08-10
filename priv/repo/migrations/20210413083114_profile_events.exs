defmodule TdDd.Repo.Migrations.ProfileEvents do
  use Ecto.Migration

  def change do
    create table("profile_events") do
      add :type, :string
      add :message, :string, size: 1_000
      add :profile_execution_id, references("profile_executions"), null: false

      timestamps(updated_at: false, type: :utc_datetime_usec)
    end
  end
end
