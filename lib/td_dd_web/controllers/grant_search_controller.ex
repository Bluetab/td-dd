defmodule TdDdWeb.GrantSearchController do
  use PhoenixSwagger
  use TdDdWeb, :controller

  import Canada, only: [can?: 2]

  alias TdDd.Grants.Grant
  alias TdDd.Grants.Search

  action_fallback(TdDdWeb.FallbackController)

  @index_worker Application.compile_env(:td_dd, :index_worker)

  swagger_path :reindex_all_grants do
    description("Reindex all grants ES indexes with DB content")
    produces("application/json")
    response(202, "Accepted")
    response(500, "Client Error")
  end

  def reindex_all_grants(conn, _params) do
    claims = conn.assigns[:current_resource]

    if can?(claims, reindex_all(Grant)) do
      @index_worker.reindex_grants(:all)
      send_resp(conn, :accepted, "")
    else
      render_error(conn, :forbidden)
    end
  end

  swagger_path :search_grants do
    description("Search for grants")
    produces("application/json")

    response(200, "Accepted")
    response(500, "Client Error")
  end

  def search_grants(conn, params) do
    claims = conn.assigns[:current_resource]
    manage_permission = can?(claims, manage(Grant))
    user_permissions = %{manage_grants: manage_permission}
    %{total: total} = response = search(conn, params, :by_permissions)

    conn
    |> put_resp_header("x-total-count", "#{total}")
    |> render("search.json", search_assigns(response, user_permissions))
  end

  def search_my_grants(conn, params) do
    claims = conn.assigns[:current_resource]
    manage_permission = can?(claims, manage(Grant))
    user_permissions = %{manage_grants: manage_permission}
    %{total: total} = response = search(conn, params, :by_user)

    conn
    |> put_resp_header("x-total-count", "#{total}")
    |> render("search.json", search_assigns(response, user_permissions))
  end

  defp search(_conn, %{"scroll_id" => _scroll_id, "scroll" => _scroll} = params, _by) do
    Search.scroll_grants(params)
  end

  defp search(conn, params, by) do
    page = Map.get(params, "page", 0)
    size = Map.get(params, "size", 20)
    claims = conn.assigns[:current_resource]

    params
    |> Map.put_new("without", "deleted_at")
    |> Map.drop(["page", "size"])
    |> search(claims, page, size, by)
  end

  defp search(params, claims, page, size, :by_user) do
    Search.search_by_user(params, claims, page, size)
  end

  defp search(params, claims, page, size, :by_permissions) do
    Search.search(params, claims, page, size)
  end

  defp search_assigns(%{results: grants, scroll_id: scroll_id}, _user_permissions) do
    [grants: grants, scroll_id: scroll_id]
  end

  defp search_assigns(%{results: grants, aggregations: aggregations}, user_permissions) do
    [grants: grants, filters: aggregations, user_permissions: user_permissions]
  end
end
