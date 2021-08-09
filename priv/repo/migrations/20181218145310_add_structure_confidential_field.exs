defmodule TdDd.Repo.Migrations.AddStructureConfidentialField do
  use Ecto.Migration

  def change do
    alter table("data_structures") do
      add :confidential, :boolean, default: false
    end
  end
end
