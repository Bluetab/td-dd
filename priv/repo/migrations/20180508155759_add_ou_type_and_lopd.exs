defmodule TdDd.Repo.Migrations.AddDataStructureOuTypeLopd do
  use Ecto.Migration

  def change do
    alter table(:data_structures) do
      add :type, :string, null: true
      add :ou,   :string, null: true
      add :lopd, :string, null: true
    end
  end
end
