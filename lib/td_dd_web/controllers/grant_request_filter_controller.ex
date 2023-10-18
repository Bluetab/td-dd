defmodule TdDdWeb.GrantRequestFilterController do
  use TdDdWeb, :controller

  alias TdDd.GrantRequests.Search

  action_fallback(TdDdWeb.FallbackController)

  def search(conn, params) do
    claims = conn.assigns[:current_resource]

    fixed_params = maybe_fix_approved_params(params)

    {:ok, filters} = Search.get_filter_values(claims, fixed_params)
    render(conn, "show.json", filters: filters)
  end

  defp maybe_fix_approved_params(
         %{"filters" => %{"must_not_approved_by" => approved_by} = filters} = params
       ) do
    must_without_approved = Map.delete(filters, "must_not_approved_by")

    params
    |> Map.put("filters", must_without_approved)
    |> Map.put("must_not", %{"approved_by" => approved_by})
  end

  defp maybe_fix_approved_params(params), do: params
end
