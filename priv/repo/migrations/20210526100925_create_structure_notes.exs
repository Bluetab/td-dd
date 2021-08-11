defmodule TdDd.Repo.Migrations.CreateStructureNotes do
  use Ecto.Migration

  @valid_statuses "'draft', 'pending_approval', 'rejected', 'published', 'versioned', 'deprecated'"
  def change do
    create_query = "CREATE TYPE structure_note_status AS ENUM (#{@valid_statuses})"
    drop_query = "DROP TYPE structure_note_status"
    execute(create_query, drop_query)

    create table("structure_notes") do
      add :status, :structure_note_status, null: false
      add :version, :integer, null: false
      add :df_content, :map, null: false
      add :data_structure_id, references("data_structures", on_delete: :delete_all), null: false

      timestamps()
    end

    create index("structure_notes", [:data_structure_id])
    create unique_index("structure_notes", [:data_structure_id, :version])
  end
end
