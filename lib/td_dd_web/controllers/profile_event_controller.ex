defmodule TdDdWeb.ProfileEventController do
  use PhoenixSwagger
  use TdDdWeb, :controller

  import Canada, only: [can?: 2]

  alias TdDd.Executions
  alias TdDd.Executions.ProfileEvent
  alias TdDd.Executions.ProfileEvents
  alias TdDd.Executions.ProfileExecution
  alias TdDdWeb.SwaggerDefinitions

  action_fallback(TdDdWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.profile_event_swagger_definitions()
  end

  swagger_path :create do
    description("Create Event")
    response(201, "Created", Schema.ref(:ProfileEventResponse))
    response(400, "Client Error")
  end

  def create(conn, %{"profile_execution_id" => id, "profile_event" => event}) do
    claims = conn.assigns[:current_resource]

    with {:can, true} <- {:can, can?(claims, create(ProfileEvent))},
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
