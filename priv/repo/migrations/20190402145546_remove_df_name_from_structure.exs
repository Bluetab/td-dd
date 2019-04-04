defmodule TdDd.Repo.Migrations.RemoveDfNameFromStructure do
  use Ecto.Migration

  def change do
    alter table(:data_structures) do
      remove(:df_name)
    end
  end
end
