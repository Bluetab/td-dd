defmodule TdDd.Repo.Migrations.RenameCsvBulkUpdateEvents do
  use Ecto.Migration

  def change do
    rename table(:csv_bulk_update_events), to: table(:file_bulk_update_events)
    rename table(:file_bulk_update_events), :csv_hash, to: :hash
  end
end
