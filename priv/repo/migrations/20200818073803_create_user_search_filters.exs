defmodule TdDd.Repo.Migrations.CreateUserSearchFilters do
  use Ecto.Migration

  def change do
    create table(:user_search_filters) do
      add :name, :string
      add :filters, :map
      add :user_id, :integer

      timestamps()
    end

    create unique_index(:user_search_filters, [:name, :user_id])
  end
end
