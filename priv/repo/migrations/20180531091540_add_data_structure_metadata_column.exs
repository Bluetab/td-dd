defmodule TdDd.Repo.Migrations.AddDataStructureModificationsColumn do
  use Ecto.Migration

  def change do
    alter table("data_structures") do
      add :metadata, :map
    end
  end
end
