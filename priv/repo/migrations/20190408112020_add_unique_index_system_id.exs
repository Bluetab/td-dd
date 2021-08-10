defmodule TdDd.Repo.Migrations.AddUniqueIndexSystemIdGroupNameExternalId do
  use Ecto.Migration

  def change do
    drop index("data_structures", [:system, :group, :name, :external_id])
    create unique_index(:data_structures, [:system_id, :group, :name, :external_id])
  end
end
