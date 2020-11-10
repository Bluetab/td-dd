defmodule TdCxWeb.JobView do
  use TdCxWeb, :view

  alias TdCxWeb.EventView
  alias TdCxWeb.SourceView

  def render("index.json", %{jobs: jobs}) do
    %{data: render_many(jobs, __MODULE__, "job.json")}
  end

  def render("search.json", %{jobs: jobs}) do
    %{data: render_many(jobs, __MODULE__, "search_item.json")}
  end

  def render("show.json", %{job: job}) do
    %{data: render_one(job, __MODULE__, "job.json")}
  end

  def render("job.json", %{job: job}) do
    job
    |> Map.take([:id, :external_id, :inserted_at, :updated_at])
    |> put_embeddings(job)
  end

  def render("search_item.json", %{job: job}) do
    Map.take(job, ["start_date", "end_date", "status", "message", "external_id", "source"])
  end

  defp put_embeddings(%{} = resp, job) do
    case embeddings(job) do
      map when map == %{} -> resp
      embeddings -> Map.put(resp, :_embedded, embeddings)
    end
  end

  defp embeddings(%{} = job) do
    job
    |> Map.take([:events, :source])
    |> Enum.reduce(%{}, fn
      {:events, events}, acc when is_list(events) ->
        Map.put(acc, :events, render_many(events, EventView, "event.json"))

      {:source, %{} = source}, acc ->
        Map.put(acc, :source, render_one(source, SourceView, "embedded.json"))

      _, acc ->
        acc
    end)
  end
end
