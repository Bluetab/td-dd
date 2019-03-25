defmodule TdDd.Repo.Migrations.CreateSystems do
  use Ecto.Migration

  def change do
    create table(:systems) do
      add :name, :string
      add :external_ref, :string
      
      timestamps()
    end

    create unique_index(:systems, [:external_ref])
  end
end
