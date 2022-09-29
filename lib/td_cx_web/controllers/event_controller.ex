defmodule TdCxWeb.EventController do
  use TdCxWeb, :controller
  use PhoenixSwagger

  alias TdCx.Events
  alias TdCx.Jobs
  alias TdCx.Jobs.Job
  alias TdCxWeb.SwaggerDefinitions

  action_fallback(TdCxWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.event_definitions()
  end

  swagger_path :index do
    description("Get events of a given job")
    produces("application/json")

    parameters do
      job_external_id(:path, :string, "job external id", required: true)
    end

    response(200, "OK", Schema.ref(:EventsResponse))
    response(403, "Forbidden")
    response(404, "Not found")
  end

  def index(conn, %{"job_external_id" => job_id}) do
    claims = conn.assigns[:current_resource]

    with %Job{events: events} = job <- Jobs.get_job!(job_id, [:events]),
         :ok <- Bodyguard.permit(Jobs, :view, claims, job) do
      render(conn, "index.json", events: events)
    end
  end

  swagger_path :create do
    description("Creates event for a given job")
    produces("application/json")

    parameters do
      job_external_id(:path, :string, "job external id", required: true)
      event(:body, Schema.ref(:CreateEvent), "Parameters used to create a event")
    end

    response(200, "OK", Schema.ref(:EventResponse))
    response(403, "Forbidden")
    response(404, "Not found")
    response(422, "Client Error")
  end

  def create(conn, %{"job_external_id" => job_external_id, "event" => event_params}) do
    claims = conn.assigns[:current_resource]

    with %Job{id: id} = job <- Jobs.get_job!(job_external_id),
         :ok <- Bodyguard.permit(Jobs, :create_event, claims, job),
         {:ok, %{event: event}} <-
           Events.create_event(Map.put(event_params, "job_id", id), claims) do
      conn
      |> put_status(:created)
      |> render("show.json", event: event)
    end
  end
end
