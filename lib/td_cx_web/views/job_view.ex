defmodule TdCxWeb.JobView do
  use TdCxWeb, :view
  alias Map.Helpers
  alias TdCxWeb.JobView

  def render("index.json", %{jobs: jobs}) do
    %{data: render_many(jobs, JobView, "job.json")}
  end

  def render("show.json", %{job: job}) do
    %{data: render_one(job, JobView, "job.json")}
  end

  def render("job.json", %{job: job}) do
    job = Helpers.atomize_keys(job)
    %{
      external_id: job.external_id,
      source: with_source(job)
    }
    |> aggregated_keys(job)
  end

  defp with_source(nil), do: nil

  defp with_source(job) do
    job
    |> Map.get(:source, %{})
    |> Map.take([:external_id, :type])
  end

  defp aggregated_keys(resp, nil), do: resp

  defp aggregated_keys(resp, job) do
    Map.merge(resp, Map.take(job, [:start_date, :end_date, :status, :message]))
  end
end
