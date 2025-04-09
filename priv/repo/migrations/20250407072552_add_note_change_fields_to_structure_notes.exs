defmodule TuApp.Repo.Migrations.AddLastChangedFieldsToStructureNotes do
  use Ecto.Migration

  def change do
    alter table(:structure_notes) do
      add :last_changed_by, :bigint, null: true
    end
  end
end
