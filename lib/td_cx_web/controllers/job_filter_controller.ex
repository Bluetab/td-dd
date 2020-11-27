defmodule TdCxWeb.JobFilterController do
  require Logger
  use TdCxWeb, :controller
  use PhoenixSwagger

  alias TdCx.Jobs.Search
  alias TdCxWeb.SwaggerDefinitions

  action_fallback(TdCxWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.filter_swagger_definitions()
  end

  swagger_path :search do
    description("List Jobs Filters")
    response(200, "OK", Schema.ref(:FilterResponse))
  end

  def search(conn, params) do
    user = conn.assigns[:current_user]
    filters = Search.get_filter_values(user, params)
    render(conn, "show.json", filters: filters)
  end
end
