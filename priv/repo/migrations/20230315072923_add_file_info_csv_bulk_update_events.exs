defmodule TdDd.Repo.Migrations.AddFileInfoCsvBulkUpdateEvents do
  use Ecto.Migration

  def change do
    alter table("csv_bulk_update_events") do
      add(:filename, :string, null: true)
    end
  end
end
