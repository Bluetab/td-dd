defmodule TdCx.Sources.Jobs do
  @moduledoc """
  The Sources.Jobs context.
  """
  import Ecto.Query, warn: false

  alias TdCx.Repo
  alias TdCx.Search.IndexWorker
  alias TdCx.Sources.Jobs.Job

  @doc """
  Returns the list of jobs.

  ## Examples

      iex> list_jobs()
      [%Job{}, ...]

  """
  def list_jobs do
    Repo.all(Job)
  end

  @doc """
  Gets a single job.

  Raises `Ecto.NoResultsError` if the Job does not exist.

  ## Examples

      iex> get_job!(123)
      %Job{}

      iex> get_job!(456)
      ** (Ecto.NoResultsError)

  """

  def get_job!(external_id, options \\ []) do
    Job
    |> Repo.get_by!(external_id: external_id)
    |> enrich(options)
  end

  @doc """
  Creates a job.

  ## Examples

      iex> create_job(%{field: value})
      {:ok, %Job{}}

      iex> create_job(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_job(attrs \\ %{}) do
    %Job{}
    |> Job.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, %Job{} = job} ->
        IndexWorker.reindex(job.id)
        {:ok, job}

      error ->
        error
    end
  end

  def metrics([]), do: Map.new()

  def metrics(events) do
    {min, max} = Enum.min_max_by(events, fn %{date: date} -> date end)

    Map.new()
    |> Map.put(:start_date, Map.get(min, :date))
    |> Map.put(:end_date, Map.get(max, :date))
    |> Map.put(:status, Map.get(max, :type))
    |> Map.put(:message, Map.get(max, :message))
  end

  defp enrich(%Job{} = job, []), do: job

  defp enrich(%Job{} = job, options) do
    Repo.preload(job, options)
  end
end
