defmodule TdCxWeb.JobController do
  use TdCxWeb, :controller

  alias TdCx.Jobs
  alias TdCx.Jobs.Job
  alias TdCx.Jobs.Search
  alias TdCx.Sources
  alias TdCx.Sources.Source

  action_fallback(TdCxWeb.FallbackController)

  def index(conn, %{"source_external_id" => source_id}) do
    claims = conn.assigns[:current_resource]
    params = %{"must" => %{"source.external_id" => source_id}}

    with :ok <- Bodyguard.permit(Jobs, :search, claims),
         %{results: results} <- Search.search_jobs(params, claims, 0, 10_000) do
      render(conn, "search.json", jobs: results)
    end
  end

  def create(conn, %{"source_external_id" => source_external_id} = params) do
    claims = conn.assigns[:current_resource]

    with %Source{id: id} = source <- Sources.get_source!(source_external_id),
         :ok <- Bodyguard.permit(Jobs, :create, claims, source: source),
         {:ok, %Job{} = job} <- params |> Map.put("source_id", id) |> Jobs.create_job() do
      conn
      |> put_status(:created)
      |> render("show.json", job: job)
    end
  end

  def show(conn, %{"external_id" => external_id}) do
    claims = conn.assigns[:current_resource]

    with %Job{} = job <- Jobs.get_job!(external_id, [:events, :source]),
         :ok <- Bodyguard.permit(Jobs, :view, claims, job) do
      render(conn, "show.json", job: job)
    end
  end

  def search(conn, params) do
    claims = conn.assigns[:current_resource]
    page = Map.get(params, "page", 0)
    size = Map.get(params, "size", 50)

    params
    |> Map.drop(["page", "size"])
    |> Search.search_jobs(claims, page, size)
    |> render_search(conn)
  end

  def render_search(results, conn) do
    jobs = Map.get(results, :results)
    total = Map.get(results, :total)

    conn
    |> put_resp_header("x-total-count", "#{total}")
    |> render("search.json", jobs: jobs)
  end
end
