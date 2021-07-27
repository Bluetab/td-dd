defmodule TdCx.Repo.Migrations.CreateJobs do
  use Ecto.Migration

  def change do
    create table(:jobs) do
      add :external_id, :uuid, null: false
      add :source_id, references(:sources), null: false

      timestamps()
    end

    create unique_index(:jobs, [:external_id])
  end
end
