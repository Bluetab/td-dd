defmodule TdDd.Repo.Migrations.AddScopeToUserSearchFilters do
  use Ecto.Migration

  @valid_scopes "'data_structure', 'rule', 'rule_implementation'"
  def change do
    create_query = "CREATE TYPE user_search_filter_scopes AS ENUM (#{@valid_scopes})"
    drop_query = "DROP TYPE user_search_filter_scopes"
    execute(create_query, drop_query)

    alter table("user_search_filters") do
      add :scope, :user_search_filter_scopes, null: false, default: "data_structure"
    end
  end
end
