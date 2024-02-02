defmodule TdDd.Repo.Migrations.AlterStructureNotesTimestamps do
  use Ecto.Migration

  def change do
    alter table("structure_notes") do
      modify(:inserted_at, :utc_datetime_usec, from: :utc_datetime)
      modify(:updated_at, :utc_datetime_usec, from: :utc_datetime)
    end
  end
end
