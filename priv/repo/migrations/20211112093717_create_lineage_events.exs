defmodule TdDd.Repo.Migrations.CreateLineageEvents do
  use Ecto.Migration

  def change do
    create table("lineage_events") do
      add(:user_id, :bigint)
      add(:graph_id, :bigint)
      add(:graph_data, :string)
      add(:graph_hash, :string)
      add(:status, :string)
      add(:task_reference, :string)
      add(:node, :string)
      add(:message, :string, size: 1_000)

      timestamps(updated_at: false, type: :utc_datetime_usec)
    end
  end
end
