defmodule TdDdWeb.ProfileExecutionController do
  use PhoenixSwagger
  use TdDdWeb, :controller

  import Canada, only: [can?: 2]

  alias TdDd.Executions
  alias TdDd.Executions.ProfileExecution
  alias TdDdWeb.SwaggerDefinitions

  action_fallback(TdDdWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.profile_execution_group_swagger_definitions()
  end

  swagger_path :index do
    description("List Executions")
    response(200, "OK", Schema.ref(:ProfileExecutionGroupsResponse))
  end

  def index(conn, params) do
    claims = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can?(claims, list(ProfileExecution))},
         executions <-
           params
           |> Executions.list_profile_executions(preload: [:data_structure, :profile])
           |> Enum.filter(&can?(claims, show(&1))) do
      render(conn, "index.json", profile_executions: executions)
    end
  end
end
