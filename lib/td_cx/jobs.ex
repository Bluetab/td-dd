defmodule TdCx.Jobs do
  @moduledoc """
  The Jobs context.
  """
  alias TdCx.Jobs.Job
  alias TdCx.Search.Indexer
  alias TdDd.Repo

  defdelegate authorize(action, user, params), to: __MODULE__.Policy

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
    Indexer.reindex([id])
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
    case Enum.max_by(events, & &1.inserted_at, DateTime) do
      %{type: type, message: message} when is_binary(message) ->
        %{status: type, message: truncate(message, opts[:max_length])}

      %{type: type} ->
        %{status: type}
    end
  end

  defp truncate(message, nil), do: message

  defp truncate(message, length) when is_integer(length) and byte_size(message) > length do
    binary_part(message, 0, length)
  end

  defp truncate(message, _), do: message

  defp enrich(%Job{} = job, []), do: job

  defp enrich(%Job{} = job, options) do
    Repo.preload(job, options)
  end
end
