defmodule TdDdWeb.UserSearchFilterView do
  use TdDdWeb, :view
  alias TdDdWeb.UserSearchFilterView

  def render("index.json", %{user_search_filters: user_search_filters}) do
    %{data: render_many(user_search_filters, UserSearchFilterView, "user_search_filter.json")}
  end

  def render("show.json", %{user_search_filter: user_search_filter}) do
    %{data: render_one(user_search_filter, UserSearchFilterView, "user_search_filter.json")}
  end

  def render("user_search_filter.json", %{user_search_filter: user_search_filter}) do
    %{
      id: user_search_filter.id,
      name: user_search_filter.name,
      filters: user_search_filter.filters,
      user_id: user_search_filter.user_id,
      scope: user_search_filter.scope,
      is_global: user_search_filter.is_global
    }
  end
end
