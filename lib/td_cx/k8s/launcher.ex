defmodule TdCx.K8s.Launcher do
  @moduledoc """
  Module to start connector jobs in Kubernetes.
  """
  alias TdCx.Jobs.Job
  alias TdCx.K8s
  alias TdCx.K8s.Manifests

  require Logger

  def launch(%Job{source: source, type: job_type, external_id: external_id}) do
    with %{type: connector_type, external_id: source_external_id} <- source,
         {:ok, [cron_job | _]} <-
           K8s.list_cronjobs(connector: connector_type, job_type: job_type, launch_type: "manual"),
         {:ok, []} <- K8s.list_jobs(job_name: external_id),
         %{"metadata" => %{"labels" => labels}} <- cron_job,
         %{} = spec <- get_in(cron_job, ["spec", "jobTemplate", "spec"]),
         %{} = job <- Manifests.job(external_id, source_external_id, spec, labels),
         {:ok, res} <- K8s.create_job(job) do
      Logger.info("Started job #{external_id} for source #{source_external_id}")
      {:ok, res}
    else
      {:ok, []} ->
        Logger.warn("No cronjob found for job #{external_id}")
        {:error, :not_found}

      {:ok, [_ | _]} ->
        Logger.warn("Job #{external_id} already exists")
        {:error, :exists}

      {:error, e} ->
        Logger.warn("Error starting job #{external_id}: #{inspect(e)}")
        {:error, e}

      _ ->
        Logger.warn("Error starting job #{external_id}")
        {:error, :invalid}
    end
  end
end
