defmodule TdDd.Repo.Migrations.ReAlterStructureNotesTimestamps do
  use Ecto.Migration

  def change do
    alter table("structure_notes") do
      modify(:inserted_at, :utc_datetime , from: :utc_datetime_usec)
      modify(:updated_at,  :utc_datetime , from: :utc_datetime_usec)
    end
  end
end
