defmodule TdDqWeb.ExecutionSearchController do
  use TdDqWeb, :controller

  alias TdDqWeb.ExecutionController

  action_fallback(TdDqWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.execution_group_swagger_definitions()
  end

  swagger_path :create do
    description("Searches for Executions")
    produces("application/json")

    response(200, "OK", Schema.ref(:ExecutionGroupsResponse))
    response(400, "Client Error")
  end

  def create(conn, %{} = params) do
    conn
    |> put_view(TdDqWeb.ExecutionView)
    |> ExecutionController.index(params)
  end
end
