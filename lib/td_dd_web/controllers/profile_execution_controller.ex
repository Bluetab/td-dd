defmodule TdDdWeb.ProfileExecutionController do
  use TdDdWeb, :controller

  alias TdDd.Executions
  alias TdDd.Executions.ProfileExecution

  action_fallback(TdDdWeb.FallbackController)

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
