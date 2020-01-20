defmodule TdCxWeb.JobView do
  use TdCxWeb, :view
  alias TdCxWeb.JobView

  def render("index.json", %{jobs: jobs}) do
    %{data: render_many(jobs, JobView, "job.json")}
  end

  def render("show.json", %{job: job}) do
    %{data: render_one(job, JobView, "job.json")}
  end

  def render("job.json", %{job: job}) do
    %{
      external_id: job.external_id,
      source_id: job.source_id
    }
  end
end
