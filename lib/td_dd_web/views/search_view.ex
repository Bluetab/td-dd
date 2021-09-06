defmodule TdDdWeb.SearchView do
  use TdDdWeb, :view
  use TdHypermedia, :view

  alias TdDdWeb.GrantView

  def render("search.json", %{
        grants: grants,
        filters: filters,
        user_permissions: user_permissions
      }) do
    %{
      filters: filters,
      data: render_many(grants, GrantView, "grant.json"),
      user_permissions: user_permissions
    }
  end
end
