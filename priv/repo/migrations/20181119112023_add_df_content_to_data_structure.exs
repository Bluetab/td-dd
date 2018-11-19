defmodule TdDd.Repo.Migrations.AddDfContentToDataStructure do
  use Ecto.Migration

  def change do
    alter table(:data_structures) do
      add :df_name, :string
      add :df_content, :map
      remove :lopd
    end
  end
end
