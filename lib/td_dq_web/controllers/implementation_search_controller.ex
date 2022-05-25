defmodule TdDqWeb.ImplementationSearchController do
  use TdDqWeb, :controller

  import Canada, only: [can?: 2]

  alias TdDq.Auth.Claims
  alias TdDq.Implementations.Implementation
  alias TdDq.Rules.Search

  action_fallback(TdDqWeb.FallbackController)

  @index_worker Application.compile_env(:td_dd, :dq_index_worker)
  @default_page 0
  @default_size 20

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
    |> put_view(TdDqWeb.SearchView)
    |> put_resp_header("x-total-count", "#{total}")
    |> put_actions(claims)
    |> render("search.json", response)
  end

  swagger_path :reindex do
    description("Reindex implementation index with DB content")
    produces("application/json")

    response(202, "Accepted")
    response(500, "Client Error")
  end

  def reindex(conn, _params) do
    @index_worker.reindex_implementations(:all)
    send_resp(conn, :accepted, "")
  end

  defp search_assigns(%{results: implementations, scroll_id: scroll_id}) do
    [implementations: implementations, scroll_id: scroll_id]
  end

  defp search_assigns(%{results: implementations, aggregations: aggregations}) do
    [implementations: implementations, filters: aggregations]
  end

  defp search_assigns(%{results: implementations}) do
    [implementations: implementations]
  end

  defp get_user_permissions(%Claims{} = claims, implementations) do
    manage_implementation? = can?(claims, manage_implementations(Implementation))
    manage_raw_implementation? = can?(claims, manage_raw_implementations(Implementation))

    manage_ruleless_implementation? =
      can?(claims, manage_ruleless_implementations(Implementation))

    execute? = Enum.any?(implementations, &can?(claims, execute(&1)))

    %{
      manage_implementations: manage_implementation?,
      manage_raw_implementations: manage_raw_implementation?,
      manage_ruleless_implementations: manage_ruleless_implementation?,
      execute: execute?
    }
  end

  defp do_search(_claims, %{"scroll" => _, "scroll_id" => _} = params) do
    Search.scroll_implementations(params)
  end

  defp do_search(claims, params) do
    page = Map.get(params, "page", @default_page)
    size = Map.get(params, "size", @default_size)

    params
    |> Map.put("without", "deleted_at")
    |> Map.drop(["page", "size"])
    |> Search.search_implementations(claims, page, size)
  end

  defp put_actions(conn, %{} = claims) do
    if can?(claims, upload(TdDq.Rules.RuleResult)) do
      actions = %{
        "uploadResults" => %{href: Routes.rule_result_path(conn, :create), method: "POST"}
      }

      assign(conn, :actions, actions)
    else
      conn
    end
  end
end
