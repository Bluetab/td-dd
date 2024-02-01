defmodule TdDd.Repo.Migrations.DropDescriptionInDataStructureTag do
  use Ecto.Migration

  def change do
    alter table("data_structure_tags") do
      remove :description
    end
  end
end
