defmodule TdDdWeb.ExecutionController do
  use PhoenixSwagger
  use TdDdWeb, :controller

  import Canada, only: [can?: 2]

  alias TdDd.Executions
  alias TdDd.Executions.Execution
  alias TdDdWeb.SwaggerDefinitions

  action_fallback(TdDdWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.execution_group_swagger_definitions()
  end

  swagger_path :index do
    description("List Executions")
    response(200, "OK", Schema.ref(:ExecutionGroupsResponse))
  end

  def index(conn, params) do
    claims = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can?(claims, list(Execution))},
         executions <- Executions.list_executions(params, preload: [:data_structure, :profile]) do
      render(conn, "index.json", executions: executions)
    end
  end
end
