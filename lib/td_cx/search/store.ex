defmodule TdCx.Search.Store do
  @moduledoc """
  Elasticsearch store implementation for Cx
  """

  @behaviour Elasticsearch.Store

  import Ecto.Query

  alias TdCluster.Cluster.TdDd.Tasks
  alias TdCx.Jobs.Job
  alias TdDd.Repo

  @impl true
  def stream(Job = schema) do
    count = Repo.aggregate(Job, :count, :id)
    Tasks.log_start_stream(count)

    result =
      schema
      |> Repo.stream()
      |> Repo.stream_preload(1000, [:source, :events])

    Tasks.log_progress(count)

    result
  end

  @impl true
  def transaction(fun) do
    {:ok, result} = Repo.transaction(fun, timeout: :infinity)
    result
  end

  def stream(Job = schema, ids) do
    count = Repo.aggregate(Job, :count, :id)
    Tasks.log_start_stream(count)

    from(job in schema)
    |> where([job], job.id in ^ids)
    |> select([job], job)
    |> Repo.stream()
    |> Repo.stream_preload(1000, [:source, :events])
  end
end
