defmodule TdCxWeb.JobController do
  use TdCxWeb, :controller
  use PhoenixSwagger

  import Canada, only: [can?: 2]

  alias TdCx.Jobs
  alias TdCx.Jobs.Job
  alias TdCx.Jobs.Search
  alias TdCx.Sources
  alias TdCx.Sources.Source
  alias TdCxWeb.ErrorView
  alias TdCxWeb.SwaggerDefinitions

  action_fallback(TdCxWeb.FallbackController)

  def swagger_definitions do
    SwaggerDefinitions.job_definitions()
  end

  swagger_path :index do
    description("Get jobs of a given source")
    produces("application/json")

    parameters do
      source_external_id(:path, :string, "source external id", required: true)
    end

    response(200, "OK", Schema.ref(:JobsResponse))
    response(403, "Forbidden")
    response(404, "Not found")
  end

  def index(conn, %{"source_external_id" => source_id}) do
    claims = conn.assigns[:current_resource]
    params = %{"filters" => %{"source.external_id" => source_id}}

    with true <- can?(claims, index(Job)),
         %{results: results} <- Search.search_jobs(params, claims, 0, 10_000) do
      render(conn, "search.json", jobs: results)
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

  swagger_path :create do
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

  def create(conn, %{"source_external_id" => source_external_id} = params) do
    claims = conn.assigns[:current_resource]

    with true <- can?(claims, create(Job)),
         %Source{id: id} <- Sources.get_source!(source_external_id),
         {:ok, %Job{} = job} <- params |> Map.put("source_id", id) |> Jobs.create_job() do
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

  swagger_path :show do
    description("Get job with the given external_id")
    produces("application/json")

    parameters do
      external_id(:path, :string, "external id of job", required: true)
    end

    response(200, "OK", Schema.ref(:JobResponse))
    response(403, "Forbidden")
    response(422, "Client Error")
  end

  def show(conn, %{"external_id" => external_id}) do
    claims = conn.assigns[:current_resource]

    with true <- can?(claims, show(Job)),
         %Job{} = job <- Jobs.get_job!(external_id, [:events, :source]) do
      render(conn, "show.json", job: job)
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

  swagger_path :search do
    description("Search jobs")

    parameters do
      search(:body, Schema.ref(:JobFilterRequest), "Search query and filter parameters")
    end

    response(200, "OK", Schema.ref(:JobsResponse))
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
