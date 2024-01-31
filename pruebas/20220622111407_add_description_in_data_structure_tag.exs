defmodule TdDd.Repo.Migrations.AddDescriptionInDataStructureTag do
  use Ecto.Migration

  def change do
    alter table("data_structure_tags") do
      add :description, :string, size: 1_000, default: nil
    end
  end
end
