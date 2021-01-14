defmodule TdDqWeb.RuleFilterController do
  use TdDqWeb, :controller

  alias TdDq.Rules.Search

  require Logger

  action_fallback(TdDqWeb.FallbackController)

  plug :put_view, TdDqWeb.FilterView

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
    claims = conn.assigns[:current_resource]
    filters = Search.get_filter_values(claims, params)
    render(conn, "show.json", filters: filters)
  end
end
