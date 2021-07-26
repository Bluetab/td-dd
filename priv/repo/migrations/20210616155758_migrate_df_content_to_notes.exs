defmodule TdDd.Repo.Migrations.MigrateDfContentToNotes do
  use Ecto.Migration

  import Ecto.Query
  alias TdDd.Repo

  def up do
    now = DateTime.utc_now()

    structure_notes_query =
      "data_structures"
      |> where([s], not is_nil(s.df_content))
      |> select([s], %{
        df_content: s.df_content,
        data_structure_id: s.id,
        version: ^1,
        status: ^"published",
        inserted_at: ^now,
        updated_at: ^now
      })

    Repo.insert_all("structure_notes", structure_notes_query)

    alter table(:data_structures) do
      remove :df_content
    end
  end

  def down do
    alter table(:data_structures) do
      add :df_content, :map
    end

    flush()

    update_query =
      from(
        ds in "data_structures",
        join: sn in "structure_notes",
        on: [data_structure_id: ds.id, status: "published"],
        update: [set: [df_content: sn.df_content]]
      )

    Repo.update_all(update_query, [])

    Repo.delete_all("structure_notes")
  end
end
