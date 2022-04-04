defmodule TdDd.Repo.Migrations.AlterJobTimestamps do
  use Ecto.Migration

  @set_updated_at """
  WITH latest_events AS (
    SELECT e.job_id, MAX(e.inserted_at) AS ts
    FROM events e
    GROUP BY e.job_id
  )
  UPDATE jobs SET updated_at = latest_events.ts
  FROM latest_events
  WHERE jobs.id = latest_events.job_id
  """

  def change do
    alter table("jobs") do
      modify(:inserted_at, :utc_datetime_usec, from: :naive_datetime)
      modify(:updated_at, :utc_datetime_usec, from: :naive_datetime)
    end

    execute(@set_updated_at, "")
  end
end
