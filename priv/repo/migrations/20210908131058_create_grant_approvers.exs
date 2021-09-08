defmodule TdDd.Repo.Migrations.CreateGrantApprovers do
  use Ecto.Migration

  def change do
    create table(:grant_approvers) do
      add :name, :string, null: false

      timestamps()
    end

    create unique_index(:grant_approvers, [:name])
  end
end
