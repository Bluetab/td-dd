defmodule TruedatWeb.UploadJobController do
  use TruedatWeb, :controller

  alias Truedat.Audit.UploadJobs

  action_fallback(TruedatWeb.FallbackController)

  def index(conn, params) do
    %{user_id: user_id} = conn.assigns[:current_resource]

    opts = build_opts(params, user_id)
    jobs = UploadJobs.list_jobs(opts)

    render(conn, "index.json", jobs: jobs)
  end

  def show(conn, %{"id" => job_id}) do
    %{user_id: user_id} = conn.assigns[:current_resource]

    case UploadJobs.get_job(job_id) do
      %{user_id: ^user_id} = job ->
        render(conn, "show.json", job: job)

      _ ->
        send_resp(conn, :not_found, "")
    end
  end

  defp build_opts(params, user_id) do
    opts = [user_id: user_id]

    params
    |> Map.get("scope")
    |> case do
      nil -> opts
      scope -> Keyword.put(opts, :scope, scope)
    end
  end
end
