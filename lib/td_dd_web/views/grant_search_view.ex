defmodule TdDdWeb.GrantSearchView do
  use TdDdWeb, :view

  alias TdDdWeb.GrantView

  def render("search.json", %{grants: grants} = assigns) do
    %{
      data: render_many(grants, GrantView, "grant.json")
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
