defmodule TdDdWeb.DataStructureFilterController do
  require Logger
  use TdDdWeb, :controller
  use PhoenixSwagger

  alias TdDd.DataStructure.Search
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
    user = conn.assigns[:current_user]
    filters = Search.get_filter_values(user)
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
    user = conn.assigns[:current_user]
    filters = Search.get_filter_values(user, params)
    render(conn, "show.json", filters: filters)
  end
end
