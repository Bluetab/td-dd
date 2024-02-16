defmodule TdDqWeb.QualityEventController do
  # use PhoenixSwagger
  use TdDqWeb, :controller

  alias TdDq.Events.QualityEvent
  alias TdDq.Events.QualityEvents
  alias TdDq.Executions
  alias TdDq.Executions.Execution
  alias TdDqWeb.SwaggerDefinitions

  action_fallback(TdDqWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.quality_event_swagger_definitions()
  end

  swagger_path :create do
    description("Create Event")
    response(201, "Created", Schema.ref(:QualityEventResponse))
    response(400, "Client Error")
  end

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
