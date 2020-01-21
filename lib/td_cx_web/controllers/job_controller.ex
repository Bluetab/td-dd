defmodule TdCxWeb.JobController do
  use TdCxWeb, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias TdCx.Sources
  alias TdCx.Sources.Jobs
  alias TdCx.Sources.Jobs.Job
  alias TdCx.Sources.Jobs.Search
  alias TdCx.Sources.Source
  alias TdCxWeb.ErrorView
  alias TdCxWeb.SwaggerDefinitions

  action_fallback(TdCxWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.job_definitions()
  end

  swagger_path :source_jobs do
    description("Get jobs of a given source")
    produces("application/json")

    parameters do
      source_external_id(:path, :string, "source external id", required: true)
    end

    response(200, "OK", Schema.ref(:JobsResponse))
    response(403, "Forbidden")
    response(404, "Not found")
  end

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

  swagger_path :create_job do
    description("Creates job of a given source")
    produces("application/json")

    parameters do
      source_external_id(:path, :string, "source external id", required: true)
    end

    response(200, "OK", Schema.ref(:JobResponse))
    response(403, "Forbidden")
    response(404, "Not found")
    response(422, "Client Error")
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

  swagger_path :search do
    description("Search jobs")

    parameters do
      search(
        :body,
        Schema.ref(:JobFilterRequest),
        "Search query and filter parameters"
      )
    end

    response(200, "OK", Schema.ref(:JobsResponse))
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
