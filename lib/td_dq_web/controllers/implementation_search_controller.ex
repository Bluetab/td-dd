defmodule TdDqWeb.ImplementationSearchController do
  use TdDqWeb, :controller

  import Canada.Can, only: [can?: 3]

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
    %{results: _implementations, total: total} = response = do_search(claims, params)

    response = search_assigns(response)

    conn
    |> assign(:actions, build_actions(conn, params))
    |> put_view(TdDqWeb.SearchView)
    |> put_resp_header("x-total-count", "#{total}")
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

  defp build_actions(conn, %{} = params) do
    claims = conn.assigns[:current_resource]

    params
    |> available_actions()
    |> Enum.filter(&can?(claims, &1, Implementation))
    |> Map.new(&{&1, build_action(conn, &1)})
  end

  defp build_action(conn, "uploadResults"),
    do: %{href: Routes.rule_result_path(conn, :create), method: "POST"}

  defp build_action(_conn, _action), do: %{method: "POST"}

  defp available_actions(%{"filters" => %{"status" => ["published"]}}) do
    # TODO: maybe exclude "execute" if no implementations are executable?
    ["uploadResults", "execute", "createRaw", "create", "download"]
  end

  defp available_actions(_) do
    ["createRaw", "create", "download", "load"]
  end
end
