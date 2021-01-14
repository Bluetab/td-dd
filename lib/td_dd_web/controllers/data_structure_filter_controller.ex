defmodule TdDdWeb.DataStructureFilterController do
  require Logger
  use TdDdWeb, :controller
  use PhoenixSwagger

  alias TdDd.DataStructures.Search
  alias TdDdWeb.SwaggerDefinitions

  action_fallback(TdDdWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.filter_swagger_definitions()
  end

  swagger_path :index do
    description("List Data Structure Filters")
    response(200, "OK", Schema.ref(:FilterResponse))
  end

  def index(conn, _params) do
    claims = conn.assigns[:current_resource]
    permission = conn.assigns[:search_permission]
    filters = Search.get_filter_values(claims, permission, %{})
    render(conn, "show.json", filters: filters)
  end

  swagger_path :search do
    description("List Data Structure Filters")

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
end
