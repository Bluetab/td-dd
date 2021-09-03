defmodule TdDdWeb.SearchView do
  use TdDdWeb, :view
  use TdHypermedia, :view

  alias TdDdWeb.GrantView

  def render("search.json", %{
        grants: grants,
        filters: filters,
        user_permissions: user_permissions
      }) do
    IO.puts("RENDER SEARCH.JSON")
    #IO.inspect(grants, label: "grants search.json", limit: :infinity)
    %{
      filters: filters,
      data: render_many(grants, GrantView, "grant.json"),
      user_permissions: user_permissions
    }
  end
end
