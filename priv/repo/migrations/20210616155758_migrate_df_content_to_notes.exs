defmodule TdDd.Repo.Migrations.MigrateDfContentToNotes do
  use Ecto.Migration

  import Ecto.Query
  alias TdDd.Repo

  def up do
    now = DateTime.utc_now()
    structure_notes = "data_structures"
      |> where([s], not is_nil(s.df_content) )
      |> select( [:df_content, :id] )
      |> Repo.all
      |> Enum.map(fn %{df_content: df_content, id: id} ->
        %{
          version: 1,
          status: "published",
          df_content: df_content,
          data_structure_id: id,
          inserted_at: now,
          updated_at: now
        }
      end)
    Repo.insert_all "structure_notes", structure_notes

    alter table(:data_structures) do
      remove :df_content
    end
  end

  def down do
    alter table(:data_structures) do
      add :df_content, :map
    end

    flush()

    "structure_notes"
    |> where([s], s.status == "published")
    |> select( [:df_content, :data_structure_id] )
    |> Repo.all
    |> Enum.map(fn %{df_content: df_content, data_structure_id: id} ->
      %{
        id: id,
        df_content: df_content
      }
    end)
    |> Enum.each(fn %{id: id, df_content: df_content} ->
      from(p in "data_structures")
      |> where([d], d.id == ^id)
      |> update([_], set: [df_content: ^df_content])
      |> Repo.update_all([])
    end)

    Repo.delete_all("structure_notes")
  end
end
