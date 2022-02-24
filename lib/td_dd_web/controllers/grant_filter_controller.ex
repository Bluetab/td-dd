defmodule TdDdWeb.GrantFilterController do
  use TdDdWeb, :controller
  use PhoenixSwagger

  alias TdDd.Grants.Search
  alias TdDdWeb.SwaggerDefinitions

  require Logger

  plug(TdDdWeb.SearchPermissionPlug)

  action_fallback(TdDdWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.filter_swagger_definitions()
  end

  swagger_path :search do
    description("List Grant Filters")

    parameters do
      search(:body, Schema.ref(:FilterRequest), "Filter parameters")
    end

    response(200, "OK", Schema.ref(:FilterResponse))
  end

  def search(conn, params) do
    claims = conn.assigns[:current_resource]
    params = Map.put(params, "without", "deleted_at")
    {:ok, filters} = Search.get_filter_values(claims, params)
    render(conn, "show.json", filters: filters)
  end

  def search_mine(conn, params) do
    %{user_id: user_id} = claims = conn.assigns[:current_resource]
    params = Map.put(params, "without", "deleted_at")
    {:ok, filters} = Search.get_filter_values(claims, params, user_id)
    render(conn, "show.json", filters: filters)
  end
end
