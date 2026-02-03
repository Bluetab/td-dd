defmodule TruedatWeb.UploadJobView do
  use TruedatWeb, :view

  def render("index.json", %{jobs: jobs}) do
    %{
      data: Enum.map(jobs, &job_json/1)
    }
  end

  def render("show.json", %{job: job}) do
    %{data: job_json(job)}
  end

  defp job_json(job) do
    job
    |> Map.take([
      :id,
      :user_id,
      :hash,
      :filename,
      :scope,
      :inserted_at,
      :latest_status,
      :latest_event_at,
      :latest_event_response
    ])
    |> maybe_render_events(job)
  end

  defp maybe_render_events(json, %{events: [_ | _] = events}) do
    Map.put(json, :events, Enum.map(events, &event_json/1))
  end

  defp maybe_render_events(json, _), do: json

  defp event_json(event) do
    Map.take(event, [:id, :status, :response, :inserted_at])
  end
end
