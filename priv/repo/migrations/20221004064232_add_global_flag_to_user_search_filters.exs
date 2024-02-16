defmodule TdDd.Repo.Migrations.AddGlobalFlagToUserSearchFilters do
  use Ecto.Migration

  def change do
    alter table("user_search_filters") do
      add :is_global, :boolean, default: false
    end
  end
end
