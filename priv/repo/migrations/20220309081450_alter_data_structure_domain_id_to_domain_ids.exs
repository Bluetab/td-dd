defmodule TdDd.Repo.Migrations.AlterDataStructureDomainIdToDomainIds do
  use Ecto.Migration

  def change do
    ["data_structures", "grant_requests"]
    |> Enum.each(&multiple_domain_ids_support_for(&1))
  end

  defp multiple_domain_ids_support_for(table_name) do
    alter table(table_name) do
      add :domain_ids, {:array, :integer}, default: []
    end

    execute(
      "update #{table_name} set domain_ids = array[domain_id] where domain_id is not null",
      "update #{table_name} set domain_id = domain_ids[1] where array_length(domain_ids, 1) > 0"
    )

    alter table(table_name) do
      remove :domain_id, :integer, null: true
    end
  end
end
