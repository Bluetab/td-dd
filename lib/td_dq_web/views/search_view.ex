defmodule TdDqWeb.SearchView do
  use TdDqWeb, :view
  use TdHypermedia, :view

  alias TdDqWeb.ImplementationView
  alias TdDqWeb.RuleView

  def render("search.json", %{
        rules: rules,
        filters: filters,
        user_permissions: user_permissions
      }) do
    %{
      filters: filters,
      data: render_many(rules, RuleView, "rule.json"),
      user_permissions: user_permissions
    }
  end

  def render("search.json", %{
        implementations: implementations,
        filters: filters,
        user_permissions: user_permissions
      }) do
    %{
      data: render_many(implementations, ImplementationView, "implementation.json"),
      filters: filters,
      user_permissions: user_permissions
    }
  end
end
