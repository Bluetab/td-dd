defmodule TdDd.Repo.Migrations.AlterDataStructureDomainIdToDomainIds do
  use Ecto.Migration

  def change do
    for table <- ["data_structures", "grant_requests"] do
      change_domain_id_to_domain_ids(table)
    end
  end

  defp change_domain_id_to_domain_ids(table_name) do
    alter table(table_name) do
      add :domain_ids, {:array, :integer}, default: [], null: false
    end

    execute(
      "update #{table_name} set domain_ids = array[domain_id] where domain_id is not null",
      "update #{table_name} set domain_id = domain_ids[1]"
    )

    alter table(table_name) do
      remove :domain_id, :integer, null: true
    end
  end
end
