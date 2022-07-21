defmodule TdDd.Repo.Migrations.AddDataStructuresAlias do
  use Ecto.Migration

  def change do
    alter table("data_structures") do
      add :alias, :string
    end

    execute(
      """
      update data_structures ds
      set alias = n.alias
      from (
        select data_structure_id, df_content->>'alias' as alias
        from structure_notes
        where status = 'published'
        and df_content ? 'alias'
      ) as n
      where ds.id = n.data_structure_id
      """,
      ""
    )
  end
end
