defmodule TdCxWeb.EventController do
  use TdCxWeb, :controller

  import Canada, only: [can?: 2]

  alias TdCx.Sources.Events
  alias TdCx.Sources.Events.Event
  alias TdCx.Sources.Jobs
  alias TdCx.Sources.Jobs.Job
  alias TdCxWeb.ErrorView

  action_fallback TdCxWeb.FallbackController

  def job_events(conn, %{"job_external_id" => job_id}) do
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

  def create_event(conn, %{"job_external_id" => job_external_id, "event" => event_params}) do
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
