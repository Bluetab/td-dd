defmodule TdDdWeb.GrantFilterController do
  require Logger
  use TdDdWeb, :controller
  use PhoenixSwagger

  alias TdDd.Grants.Search
  alias TdDdWeb.SwaggerDefinitions

  plug(TdDdWeb.SearchPermissionPlug)

  action_fallback(TdDdWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.filter_swagger_definitions()
  end

  swagger_path :index do
    description("List Grant Filters")
    response(200, "OK", Schema.ref(:FilterResponse))
  end

  def index(conn, _params) do
    claims = conn.assigns[:current_resource]
    permission = conn.assigns[:search_permission]
    filters = Search.get_filter_values(claims, permission, :grants)
    render(conn, "show.json", filters: filters)
  end

  swagger_path :search do
    description("List Grant Filters")

    parameters do
      search(
        :body,
        Schema.ref(:FilterRequest),
        "Filter parameters"
      )
    end

    response(200, "OK", Schema.ref(:FilterResponse))
  end

  def search(conn, params) do
    claims = conn.assigns[:current_resource]
    permission = conn.assigns[:search_permission]
    params = Map.put(params, :without, ["deleted_at"])
    filters = Search.get_filter_values(claims, permission, params)
    render(conn, "show.json", filters: filters)
  end

  def search_mine(conn, params) do
    %{user_id: user_id} = conn.assigns[:current_resource]
    params = Map.put(params, :without, ["deleted_at"])
    filters = Search.get_filter_values(user_id, params)
    render(conn, "show.json", filters: filters)
  end
end
