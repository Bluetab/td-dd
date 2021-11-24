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

  def render(
        "search.json",
        %{
          implementations: implementations
        } = assigns
      ) do
    %{
      data: render_many(implementations, ImplementationView, "implementation.json")
    }
    |> with_user_permissions(assigns)
    |> with_scroll_id(assigns)
    |> with_filters(assigns)
  end

  defp with_user_permissions(payload, %{user_permissions: user_permissions}) do
    Map.put(payload, :user_permissions, user_permissions)
  end

  defp with_user_permissions(payload, _assigns), do: payload

  defp with_scroll_id(payload, %{scroll_id: scroll_id}) do
    Map.put(payload, :scroll_id, scroll_id)
  end

  defp with_scroll_id(payload, _assigns), do: payload

  defp with_filters(payload, %{filters: filters}) do
    Map.put(payload, :filters, filters)
  end

  defp with_filters(payload, _assigns), do: payload
end
