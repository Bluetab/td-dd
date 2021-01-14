defmodule TdDqWeb.ExecutionController do
  use TdDqWeb, :controller

  import Canada, only: [can?: 2]

  alias TdDq.Executions
  alias TdDq.Executions.Execution

  action_fallback(TdDqWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.execution_group_swagger_definitions()
  end

  swagger_path :index do
    description("List Executions")
    response(200, "OK", Schema.ref(:ExecutionGroupsResponse))
  end

  def index(conn, _params) do
    claims = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can?(claims, list(Execution))},
         executions <- Executions.list_executions(%{}, preload: [:implementation, :result]) do
      render(conn, "index.json", executions: executions)
    end
  end
end
