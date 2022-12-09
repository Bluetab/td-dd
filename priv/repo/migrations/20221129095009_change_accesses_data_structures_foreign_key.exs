defmodule TdDd.Repo.Migrations.ChangeAccessesDataStructuresForeignKey do
  use Ecto.Migration

  def change do
    drop unique_index("accesses", [:data_structure_external_id, :source_user_name, :accessed_at])

    alter table("accesses") do
      add :data_structure_id, :bigint
    end

    execute(
      "with s as (select id, external_id from data_structures) update accesses a set data_structure_id = s.id from s where data_structure_external_id = s.external_id",
      "with s as (select id, external_id from data_structures) update accesses a set data_structure_external_id = s.external_id from s where data_structure_id = s.id"
    )

    execute("delete from accesses where data_structure_id is null", "")

    alter table("accesses") do
      modify :data_structure_id, references("data_structures", on_delete: :delete_all),
        null: false,
        from: :bigint
    end

    alter table("accesses") do
      remove :data_structure_external_id,
             references("data_structures",
               column: :external_id,
               type: :string,
               on_delete: :nothing
             )
    end

    create unique_index("accesses", [:data_structure_id, :source_user_name, :accessed_at])
    create index("accesses", [:data_structure_id])
  end
end
