defmodule TdDdWeb.GrantRequestSearchView do
  use TdDdWeb, :view

  alias TdDdWeb.GrantRequestView

  def render("search.json", %{grant_request: grant_request, permissions: permissions} = assigns) do
    result = %{
      data: render_many(grant_request, GrantRequestView, "grant_request_search.json")
    }

    result
    |> with_filters(assigns)
    |> with_scroll_id(assigns)
    |> add_permissions(permissions)
  end

  defp add_permissions(%{} = resp, permissions) do
    Map.put(resp, :_permissions, permissions)
  end

  defp with_filters(payload, %{filters: filters}) do
    Map.put(payload, :filters, filters)
  end

  defp with_filters(payload, _assigns), do: payload

  defp with_scroll_id(payload, %{scroll_id: scroll_id}) do
    Map.put(payload, :scroll_id, scroll_id)
  end

  defp with_scroll_id(payload, _assigns), do: payload
end
