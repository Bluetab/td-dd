defmodule TdCx.Search.Store do
  @moduledoc """
  Elasticsearch store implementation for Cx
  """

  @behaviour Elasticsearch.Store

  import Ecto.Query

  alias TdCx.Repo

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
    jobs = job in schema

    jobs
    |> from(
      where: job.id in ^ids,
      select: job
    )
    |> Repo.stream()
    |> Repo.stream_preload(1000, [:source, :events])
  end
end
