defmodule TdDqWeb.QualityEventController do
  #
  use TdDqWeb, :controller

  alias TdDq.Events.QualityEvent
  alias TdDq.Events.QualityEvents
  alias TdDq.Executions
  alias TdDq.Executions.Execution

  action_fallback(TdDqWeb.FallbackController)

  def create(conn, params) do
    %{"execution_id" => id, "quality_event" => event} = params
    claims = conn.assigns[:current_resource]

    with :ok <- Bodyguard.permit(Executions, :create_event, claims),
         %Execution{id: id} <- Executions.get(id),
         {:ok, %QualityEvent{} = event} <-
           QualityEvents.create_event(Map.put(event, "execution_id", id)) do
      conn
      |> put_status(:created)
      |> render("show.json", quality_event: event)
    else
      nil -> {:error, :not_found}
      error -> error
    end
  end
end
