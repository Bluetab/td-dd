defmodule TdDdWeb.ProfileEventController do
  use TdDdWeb, :controller

  alias TdDd.Executions
  alias TdDd.Executions.ProfileEvent
  alias TdDd.Executions.ProfileEvents
  alias TdDd.Executions.ProfileExecution
  alias TdDd.Profiles

  action_fallback(TdDdWeb.FallbackController)

  def create(conn, %{"profile_execution_id" => id, "profile_event" => event}) do
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Profiles, :create, claims),
         %ProfileExecution{id: id} <- Executions.get_profile_execution(id),
         {:ok, %ProfileEvent{} = event} <-
           ProfileEvents.create_event(Map.put(event, "profile_execution_id", id)) do
      conn
      |> put_status(:created)
      |> render("show.json", profile_event: event)
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end
end
