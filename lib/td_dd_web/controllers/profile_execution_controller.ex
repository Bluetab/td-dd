defmodule TdDdWeb.ProfileExecutionController do
  use PhoenixSwagger
  use TdDdWeb, :controller

  alias TdDd.Executions
  alias TdDd.Executions.ProfileExecution
  alias TdDdWeb.SwaggerDefinitions

  action_fallback(TdDdWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.profile_execution_group_swagger_definitions()
  end

  swagger_path :index do
    description("List Executions")
    response(200, "OK", Schema.ref(:ProfileExecutionsResponse))
  end

  def index(conn, params) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(TdDd.Profiles, :search, claims),
         executions <-
           params
           |> Executions.list_profile_executions(
             preload: [{:data_structure, :source}, :profile, :profile_events]
           )
           |> Enum.filter(&Bodyguard.permit?(TdDd.Profiles, :view, claims, &1)) do
      render(conn, "index.json", profile_executions: executions)
    end
  end

  swagger_path :show do
    description("Show Execution")
    response(200, "OK", Schema.ref(:ProfileExecutionsResponse))
    response(400, "Client Error")
  end

  def show(conn, %{"id" => id}) do
    claims = conn.assigns[:current_resource]

    with %ProfileExecution{} = execution <-
           Executions.get_profile_execution(id,
             preload: [:data_structure, :profile, :profile_events],
             enrich: [:latest]
           ),
         :ok <- Bodyguard.permit(TdDd.Profiles, :view, claims, execution) do
      render(conn, "show.json", profile_execution: execution)
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end
end
