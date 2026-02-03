defmodule TdDq.Repo.Migrations.RenameImplementationUploadEvents do
  use Ecto.Migration

  def up do
    rename table(:implementation_upload_jobs), to: table(:upload_jobs)
    rename table(:implementation_upload_events), to: table(:upload_events)

    alter table("upload_jobs") do
      add(:scope, :string)
    end

    execute("UPDATE upload_jobs SET scope = 'implementations'")
  end

  def down do
    alter table("upload_jobs") do
      remove(:scope)
    end

    rename table(:upload_events), to: table(:implementation_upload_events)
    rename table(:upload_jobs), to: table(:implementation_upload_jobs)
  end
end
