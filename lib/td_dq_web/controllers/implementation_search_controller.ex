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
    IO.puts("ImplementationSearchController create")
    claims = conn.assigns[:current_resource]
    page = Map.get(params, "page", 0)
    size = Map.get(params, "size", 20)

    %{
      results: implementations,
      aggregations: aggregations,
      total: total
    } =
      params
      |> Map.put(:without, ["deleted_at"])
      |> Map.drop(["page", "size"])
      |> Search.search(claims, page, size, :implementations)

    conn
    |> put_resp_header("x-total-count", "#{total}")
    |> put_view(TdDqWeb.SearchView)
    |> render("search.json",
      implementations: implementations,
      filters: aggregations,
      user_permissions: get_user_permissions(claims, implementations)
    )
  end

  defp get_user_permissions(%Claims{role: "admin"}, _implementations),
    do: %{manage: true, execute: true}

  defp get_user_permissions(%Claims{role: "service"}, _implementations),
    do: %{manage: false, execute: true}

  defp get_user_permissions(%Claims{} = claims, implementations) do
    manage? = can?(claims, manage(Implementation))
    execute? = Enum.any?(implementations, &can_execute?(claims, &1))

    %{manage: manage?, execute: execute?}
  end

  defp can_execute?(%Claims{} = claims, implementation) do
    can?(
      claims,
      execute(%{
        "business_concept_id" => Map.get(implementation, :business_concept_id),
        "resource_type" => "implementation"
      })
    )
  end
end
