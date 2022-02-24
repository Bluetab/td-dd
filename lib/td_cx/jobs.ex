defmodule TdCx.Jobs do
  @moduledoc """
  The Jobs context.
  """
  alias TdCx.Jobs.Job
  alias TdCx.Search.IndexWorker
  alias TdDd.Repo

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
    |> with_metrics()
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
    |> reindex()
  end

  defp reindex({:ok, %Job{id: id} = job}) do
    IndexWorker.reindex(id)
    {:ok, Repo.preload(job, [:source])}
  end

  defp reindex(error), do: error

  def with_metrics(%{events: events} = job) when is_list(events) do
    Map.merge(job, metrics(events))
  end

  def with_metrics(job), do: job

  def metrics(events, opts \\ [])

  def metrics([] = _events, _opts), do: Map.new()

  def metrics(events, opts) do
    {min, max} = Enum.min_max_by(events, & &1.inserted_at, DateTime)

    message = Map.get(max, :message)

    message =
      case opts[:max_length] do
        nil -> message
        length when length < byte_size(message) -> binary_part(message, 0, length)
        _ -> message
      end

    Map.new()
    |> Map.put(:start_date, Map.get(min, :inserted_at))
    |> Map.put(:end_date, Map.get(max, :inserted_at))
    |> Map.put(:status, Map.get(max, :type))
    |> Map.put(:message, message)
  end

  defp enrich(%Job{} = job, []), do: job

  defp enrich(%Job{} = job, options) do
    Repo.preload(job, options)
  end
end
