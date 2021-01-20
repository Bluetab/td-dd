defmodule TdDqWeb.SearchController do
  use TdDqWeb, :controller

  import Canada, only: [can?: 2]

  alias TdDq.Auth.Claims
  alias TdDq.Rules.Implementations.Implementation
  alias TdDq.Rules.Search
  alias TdDq.Search.IndexWorker

  plug :put_view, TdDqWeb.SearchView

  swagger_path :reindex_all_rules do
    description("Reindex rule index with DB content")
    produces("application/json")

    response(202, "Accepted")
    response(500, "Client Error")
  end

  def reindex_all_rules(conn, _params) do
    IndexWorker.reindex_rules(:all)
    send_resp(conn, :accepted, "")
  end

  swagger_path :reindex_all_implementations do
    description("Reindex implementation index with DB content")
    produces("application/json")

    response(202, "Accepted")
    response(500, "Client Error")
  end

  def reindex_all_implementations(conn, _params) do
    IndexWorker.reindex_implementations(:all)
    send_resp(conn, :accepted, "")
  end

  swagger_path :search_rules do
    description("Search for rules")
    produces("application/json")

    response(200, "Accepted")
    response(500, "Client Error")
  end

  def search_rules(conn, params) do
    page = Map.get(params, "page", 0)
    size = Map.get(params, "size", 20)
    claims = conn.assigns[:current_resource]
    manage_permission = can?(claims, manage(%{"resource_type" => "rule"}))
    user_permissions = %{manage_quality_rules: manage_permission}

    %{
      results: rules,
      aggregations: aggregations,
      total: total
    } =
      params
      |> Map.drop(["page", "size"])
      |> Search.search(claims, page, size)

    conn
    |> put_resp_header("x-total-count", "#{total}")
    |> render("search.json",
      rules: rules,
      filters: aggregations,
      user_permissions: user_permissions
    )
  end

  swagger_path :search_implementations do
    description("Search for implementations")
    produces("application/json")

    response(200, "Accepted")
    response(500, "Client Error")
  end

  def search_implementations(conn, params) do
    page = Map.get(params, "page", 0)
    size = Map.get(params, "size", 20)
    claims = conn.assigns[:current_resource]

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
