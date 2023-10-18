defmodule TdDdWeb.GrantRequestSearchView do
  use TdDdWeb, :view

  alias TdDdWeb.GrantRequestView

  def render("search.json", %{grant_request: grant_request, permissions: permissions} = assigns) do
    result = %{
      data: render_many(grant_request, GrantRequestView, "grant_request_search.json")
    }

    result
    |> with_filters(assigns)
    |> add_permissions(permissions)
  end

  defp add_permissions(%{} = resp, permissions) do
    Map.put(resp, :_permissions, permissions)
  end

  defp add_permissions(resp, _), do: resp

  defp with_filters(payload, %{filters: filters}) do
    Map.put(payload, :filters, filters)
  end

  defp with_filters(payload, _assigns), do: payload
end
