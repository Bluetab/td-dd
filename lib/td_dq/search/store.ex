defmodule TdDq.Search.Store do
  @moduledoc """
  Elasticsearch store implementation for Data Quality
  """

  @behaviour Elasticsearch.Store

  import Ecto.Query

  alias TdDq.Repo
  alias TdDq.Rules.Rule
  alias TdDq.Rules.Indexable

  @impl true
  def stream(Indexable) do
    Rule
    |> where([r], is_nil(r.deleted_at))
    |> join(:inner, [r], rt in assoc(r, :rule_type))
    |> select([r, rt], %Indexable{rule: r, rule_type: rt})
    |> Repo.stream()
  end

  @impl true
  def transaction(fun) do
    {:ok, result} = Repo.transaction(fun, timeout: :infinity)
    result
  end
end
