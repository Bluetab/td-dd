defmodule TdDd.Repo.Migrations.AlterDataStructureTypesAddFilters do
  use Ecto.Migration

  def change do
    alter table("data_structure_types") do
      add :filters, {:array, :string}, default: []
    end
  end
end
