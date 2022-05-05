defmodule TdDd.Repo.Migrations.AddCsvBulkUpdateEventsTable do
  use Ecto.Migration

  def change do
    create table("csv_bulk_update_events") do
      add(:user_id, :bigint)
      add(:response, :map)
      add(:csv_hash, :string)
      add(:status, :string)
      add(:task_reference, :string)
      add(:node, :string)
      add(:message, :string, size: 1_000)

      timestamps(updated_at: false, type: :utc_datetime_usec)
    end

  end
end
