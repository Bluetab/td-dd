defmodule TdDq.Repo.Migrations.CreateImplementationUploadEvents do
  use Ecto.Migration

  def change do
    create table("implementation_upload_jobs") do
      add(:user_id, :bigint)
      add(:hash, :string)
      add(:filename, :string)

      timestamps(updated_at: false, type: :utc_datetime_usec)
    end

    create table("implementation_upload_events") do
      add(:job_id, references("implementation_upload_jobs"))
      add(:response, :map)
      add(:status, :string)

      timestamps(updated_at: false, type: :utc_datetime_usec)
    end
  end
end
