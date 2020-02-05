defmodule TdCxWeb.EventController do
  use TdCxWeb, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias TdCx.Sources.Events
  alias TdCx.Sources.Events.Event
  alias TdCx.Sources.Jobs
  alias TdCx.Sources.Jobs.Job
  alias TdCxWeb.ErrorView
  alias TdCxWeb.SwaggerDefinitions

  action_fallback TdCxWeb.FallbackController

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
    user = conn.assigns[:current_user]

    with true <- can?(user, index(%Event{})),
         %Job{events: events} <- Jobs.get_job!(job_id, [:events]) do
      render(conn, "index.json", events: events)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")
    end
  rescue
    _e in Ecto.NoResultsError ->
      conn
      |> put_status(:not_found)
      |> put_view(ErrorView)
      |> render("404.json")
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
    user = conn.assigns[:current_user]

    with true <- can?(user, create(%Event{})),
         %Job{id: id} <- Jobs.get_job!(job_external_id),
         {:ok, %Event{} = event} <- Events.create_event(Map.put(event_params, "job_id", id)) do
      conn
      |> put_status(:created)
      |> render("show.json", event: event)
    else
      false ->
        conn
        |> put_status(:forbidden)
        |> put_view(ErrorView)
        |> render("403.json")

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(TdCxWeb.ChangesetView)
        |> render("error.json", changeset: changeset)
    end
  rescue
    _e in Ecto.NoResultsError ->
      conn
      |> put_status(:not_found)
      |> put_view(ErrorView)
      |> render("404.json")
  end
end
