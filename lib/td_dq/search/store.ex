defmodule TdDq.Search.Store do
  @moduledoc """
  Elasticsearch store implementation for Data Quality
  """

  @behaviour Elasticsearch.Store

  import Ecto.Query

  alias TdDq.Repo
  alias TdDq.Rules.Rule

  @impl true
  def stream(Rule) do
    Rule
    |> where([r], is_nil(r.deleted_at))
    |> join(:inner, [r], rt in assoc(r, :rule_type))
    |> select([r], r)
    |> Repo.stream()
    |> Enum.map(&Repo.preload(&1, :rule_type))
  end

  @impl true
  def transaction(fun) do
    {:ok, result} = Repo.transaction(fun, timeout: :infinity)
    result
  end
end
