defmodule TdDq.Search.Store do
  @moduledoc """
  Elasticsearch store implementation for Data Quality
  """

  @behaviour Elasticsearch.Store

  import Ecto.Query

  alias TdDd.Repo
  alias TdDq.Implementations.Implementation
  alias TdDq.Rules.Rule

  @impl true
  def stream(Rule = schema) do
    schema
    |> where([r], is_nil(r.deleted_at))
    |> Repo.stream()
  end

  @impl true
  def stream(Implementation = schema) do
    schema
    |> where([ri], is_nil(ri.deleted_at))
    |> Repo.stream()
    |> Repo.stream_preload(1000, :rule)
  end

  def stream(Rule = schema, ids) do
    schema
    |> where([r], is_nil(r.deleted_at))
    |> where([r], r.id in ^ids)
    |> Repo.stream()
  end

  def stream(Implementation = schema, ids) do
    schema
    |> where([ri], is_nil(ri.deleted_at))
    |> where([ri], ri.id in ^ids)
    |> Repo.stream()
    |> Repo.stream_preload(1000, :rule)
  end

  @impl true
  def transaction(fun) do
    {:ok, result} = Repo.transaction(fun, timeout: :infinity)
    result
  end
end
