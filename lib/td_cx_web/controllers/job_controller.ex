defmodule TdCxWeb.JobController do
  use TdCxWeb, :controller

  import Canada, only: [can?: 2]

  alias TdCx.Sources
  alias TdCx.Sources.Jobs
  alias TdCx.Sources.Jobs.Job
  alias TdCx.Sources.Jobs.Search
  alias TdCx.Sources.Source
  alias TdCxWeb.ErrorView

  action_fallback(TdCxWeb.FallbackController)

  def source_jobs(conn, %{"source_external_id" => source_id}) do
    user = conn.assigns[:current_user]

    with true <- can?(user, index(%Job{})),
         %Source{jobs: jobs} <- Sources.get_source!(source_id, [:jobs]) do
      render(conn, "index.json", jobs: jobs)
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

  def create_job(conn, %{"source_external_id" => source_external_id}) do
    user = conn.assigns[:current_user]

    with true <- can?(user, create(%Job{})),
         %Source{id: id} <- Sources.get_source!(source_external_id),
         {:ok, %Job{} = job} <- Jobs.create_job(%{source_id: id}) do
      conn
      |> put_status(:created)
      |> render("show.json", job: job)
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

  def search(conn, params) do
    user = conn.assigns[:current_user]
    page = params |> Map.get("page", 0)
    size = params |> Map.get("size", 50)

    params
    |> Map.drop(["page", "size"])
    |> Search.search_jobs(user, page, size)
    |> render_search(conn)
  end

  def render_search(results, conn) do
    render(conn, "index.json", jobs: results)
  end
end
