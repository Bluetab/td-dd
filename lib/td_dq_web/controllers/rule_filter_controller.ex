defmodule TdDqWeb.RuleFilterController do
  require Logger
  use TdDqWeb, :controller
  use PhoenixSwagger

  alias TdDq.Rules.Search
  alias TdDqWeb.SwaggerDefinitions

  action_fallback(TdDqWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.filter_swagger_definitions()
  end

  swagger_path :search do
    description("List Quality Rule Filters")
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
    filters = Search.get_filter_values(params)
    render(conn, "show.json", filters: filters)
  end
end
