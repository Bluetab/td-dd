defmodule TdDq.Search.Store do
  @moduledoc """
  Elasticsearch store implementation for Data Quality
  """

  @behaviour Elasticsearch.Store

  import Ecto.Query

  alias TdDq.Repo
  alias TdDq.Rules.Implementations.Implementation
  alias TdDq.Rules.Rule

  @impl true
  def stream(Rule = schema) do
    schema
    |> where([r], is_nil(r.deleted_at))
    |> select([r], r)
    |> Repo.stream()
  end

  @impl true
  def stream(Implementation = schema) do
    schema
    |> join(:inner, [ri, r], r in Rule, on: ri.rule_id == r.id)
    |> where([_ri, r], is_nil(r.deleted_at))
    |> select([ri, _r], ri)
    |> Repo.stream()
    |> Repo.stream_preload(1000, :rule)
  end

  def stream(Rule = schema, ids) do
    schema
    |> where([r], is_nil(r.deleted_at))
    |> where([r], r.id in ^ids)
    |> select([r], r)
    |> Repo.stream()
  end

  def stream(Implementation = schema, ids) do
    schema
    |> join(:inner, [ri, r], r in Rule, on: ri.rule_id == r.id)
    |> where([_ri, r], is_nil(r.deleted_at))
    |> where([ri, _r], ri.id in ^ids)
    |> select([ri, _r], ri)
    |> Repo.stream()
    |> Repo.stream_preload(1000, :rule)
  end

  @impl true
  def transaction(fun) do
    {:ok, result} = Repo.transaction(fun, timeout: :infinity)
    result
  end
end
