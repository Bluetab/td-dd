defmodule TdDqWeb.ImplementationSearchController do
  use TdDqWeb, :controller

  import Canada, only: [can?: 2]

  alias TdDq.Auth.Claims
  alias TdDq.Implementations.Implementation
  alias TdDq.Rules.Search

  action_fallback(TdDqWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.rule_result_swagger_definitions()
  end

  swagger_path :create do
    description("Search for rule implementations")
    produces("application/json")

    response(200, "OK")
    response(400, "Client Error")
  end

  def create(conn, %{} = params) do
    claims = conn.assigns[:current_resource]
    %{results: implementations, total: total} = response = do_search(claims, params)

    response =
      search_assigns(response) ++
        [user_permissions: get_user_permissions(claims, implementations)]

    conn
    |> put_resp_header("x-total-count", "#{total}")
    |> put_view(TdDqWeb.SearchView)
    |> render("search.json", response)
  end

  defp search_assigns(%{results: implementations, scroll_id: scroll_id}) do
    [implementations: implementations, scroll_id: scroll_id]
  end

  defp search_assigns(%{results: implementations, aggregations: aggregations}) do
    [implementations: implementations, filters: aggregations]
  end

  defp get_user_permissions(%Claims{role: "admin"}, _implementations),
    do: %{manage: true, execute: true}

  defp get_user_permissions(%Claims{role: "service"}, _implementations),
    do: %{manage: false, execute: true}

  defp get_user_permissions(%Claims{} = claims, implementations) do
    manage? = can?(claims, manage(Implementation))
    execute? = Enum.any?(implementations, &can?(claims, execute(&1)))

    %{manage: manage?, execute: execute?}
  end

  defp do_search(claims, params, page \\ 0, size \\ 20)

  defp do_search(_claims, %{"scroll" => _, "scroll_id" => _} = scroll_params, _page, _size) do
    Search.scroll_implementations(scroll_params)
  end

  defp do_search(claims, search_params, page, size) do
    page = Map.get(search_params, "page", page)
    size = Map.get(search_params, "size", size)

    search_params
    |> Map.put(:without, ["deleted_at"])
    |> Map.drop(["page", "size"])
    |> Search.search(claims, page, size, :implementations)
  end
end
