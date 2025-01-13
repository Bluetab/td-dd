defmodule TdCxWeb.EventController do
  use TdCxWeb, :controller

  alias TdCx.Events
  alias TdCx.Jobs
  alias TdCx.Jobs.Job

  action_fallback(TdCxWeb.FallbackController)

  def index(conn, %{"job_external_id" => job_id}) do
    claims = conn.assigns[:current_resource]

    with %Job{events: events} = job <- Jobs.get_job!(job_id, [:events]),
         :ok <- Bodyguard.permit(Jobs, :view, claims, job) do
      render(conn, "index.json", events: events)
    end
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
