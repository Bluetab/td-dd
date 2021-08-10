defmodule TdDd.Repo.Migrations.CreateQualityEvents do
  use Ecto.Migration

  def change do
    create table("quality_events") do
      add(:type, :string)
      add(:message, :string, size: 1_000)
      add(:execution_id, references("executions", on_delete: :delete_all), null: false)

      timestamps(updated_at: false, type: :utc_datetime_usec)
    end
  end
end
