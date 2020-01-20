defmodule TdCxWeb.JobController do
  use TdCxWeb, :controller

  import Canada, only: [can?: 2]

  alias TdCx.Sources
  alias TdCx.Sources.Jobs
  alias TdCx.Sources.Jobs.Job
  alias TdCx.Sources.Source
  alias TdCxWeb.ErrorView

  action_fallback TdCxWeb.FallbackController

  def source_jobs(conn, %{"source_external_id" => source_id}) do
    user = conn.assigns[:current_user]

    with true <- can?(user, show(%Source{})),
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

  # def index(conn, _params) do
  #   jobs = Jobs.list_jobs()
  #   render(conn, "index.json", jobs: jobs)
  # end

  # def create(conn, %{"job" => job_params}) do
  #   with {:ok, %Job{} = job} <- Jobs.create_job(job_params) do
  #     conn
  #     |> put_status(:created)
  #     |> put_resp_header("location", Routes.job_path(conn, :show, job))
  #     |> render("show.json", job: job)
  #   end
  # end

  # def show(conn, %{"id" => id}) do
  #   job = Jobs.get_job!(id)
  #   render(conn, "show.json", job: job)
  # end

  # def update(conn, %{"id" => id, "job" => job_params}) do
  #   job = Jobs.get_job!(id)

  #   with {:ok, %Job{} = job} <- Jobs.update_job(job, job_params) do
  #     render(conn, "show.json", job: job)
  #   end
  # end

  # def delete(conn, %{"id" => id}) do
  #   job = Jobs.get_job!(id)

  #   with {:ok, %Job{}} <- Jobs.delete_job(job) do
  #     send_resp(conn, :no_content, "")
  #   end
  # end
end
