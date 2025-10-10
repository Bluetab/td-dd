defmodule TdDqWeb.Implementation.XLSXView do
  use TdDqWeb, :view

  # Render a list of upload jobs with their events
  def render("upload_jobs.json", %{jobs: jobs}) do
    %{
      data: Enum.map(jobs, &job_json/1)
    }
  end

  # Render a single upload job with its events
  def render("upload_job.json", %{job: job}) do
    %{data: job_json(job)}
  end

  defp job_json(%{
         id: id,
         user_id: user_id,
         hash: hash,
         filename: filename,
         inserted_at: inserted_at,
         events: events,
         latest_status: latest_status,
         latest_event_at: latest_event_at,
         latest_event_response: latest_event_response
       }) do
    %{
      id: id,
      user_id: user_id,
      hash: hash,
      filename: filename,
      inserted_at: inserted_at,
      latest_status: latest_status,
      latest_event_at: latest_event_at,
      latest_event_response: latest_event_response
    }
    |> maybe_render_events(events)
  end

  defp maybe_render_events(json, [_ | _] = events) do
    Map.put(json, :events, Enum.map(events, &event_json/1))
  end

  defp maybe_render_events(json, _), do: json

  defp event_json(%{id: id, status: status, response: response, inserted_at: inserted_at}) do
    %{
      id: id,
      status: status,
      response: response,
      inserted_at: inserted_at
    }
  end
end
