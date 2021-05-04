defmodule TdDdWeb.ProfileExecutionSearchController do
  use PhoenixSwagger
  use TdDdWeb, :controller

  alias TdDdWeb.ProfileExecutionController
  alias TdDdWeb.SwaggerDefinitions

  action_fallback(TdDdWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.profile_execution_group_swagger_definitions()
  end

  swagger_path :create do
    description("Searches for Executions")
    produces("application/json")

    response(200, "OK", Schema.ref(:ProfileExecutionGroupsResponse))
    response(400, "Client Error")
  end

  def create(conn, %{} = params) do
    conn
    |> put_view(TdDdWeb.ProfileExecutionView)
    |> ProfileExecutionController.index(params)
  end
end
