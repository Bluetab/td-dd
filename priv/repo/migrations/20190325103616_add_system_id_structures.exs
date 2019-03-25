defmodule TdDd.Repo.Migrations.AddSystemIdStructures do
  use Ecto.Migration

  def change do
    alter table(:data_structures) do
      add :system_id, references(:systems)
    end
  end
end
