defmodule TdDd.Repo.Migrations.ChangeExternalIdDataStructures do
  use Ecto.Migration

  def change do
    alter table(:data_structures) do
      modify :external_id, :text
    end
  end
end
