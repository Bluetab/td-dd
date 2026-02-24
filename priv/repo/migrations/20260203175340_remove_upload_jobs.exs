defmodule TdDd.Repo.Migrations.RemoveUploadJobs do
  use Ecto.Migration

  def change do
    drop table(:upload_events)
    drop table(:upload_jobs)
  end
end
