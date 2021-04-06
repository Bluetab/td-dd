defmodule TdCx.Search.Store do
  @moduledoc """
  Elasticsearch store implementation for Cx
  """

  @behaviour Elasticsearch.Store

  import Ecto.Query

  alias TdDd.Repo

  @impl true
  def stream(schema) do
    schema
    |> Repo.stream()
    |> Repo.stream_preload(1000, [:source, :events])
  end

  @impl true
  def transaction(fun) do
    {:ok, result} = Repo.transaction(fun, timeout: :infinity)
    result
  end

  def stream(schema, ids) do
    jobs = from(job in schema)

    jobs
    |> where([job], job.id in ^ids)
    |> select([job], job)
    |> Repo.stream()
    |> Repo.stream_preload(1000, [:source, :events])
  end
end
