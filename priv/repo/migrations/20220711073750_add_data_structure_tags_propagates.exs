defmodule TdDd.Repo.Migrations.AddDataStructureTagsPropagates do
  use Ecto.Migration

  def change do
    alter table("data_structures_tags") do
      add :inherit, :boolean, default: false, nillable: false
    end
  end
end
