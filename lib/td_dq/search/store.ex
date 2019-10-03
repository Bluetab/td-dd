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
    query()
    |> Repo.stream()
    |> Stream.map(&preload/1)
  end

  @impl true
  def transaction(fun) do
    {:ok, result} = Repo.transaction(fun, timeout: :infinity)
    result
  end

  def list(ids) do
    ids
    |> query()
    |> Repo.all()
    |> Enum.map(&preload/1)
  end

  defp query do
    from(r in Rule,
      join: t in assoc(r, :rule_type),
      where: is_nil(r.deleted_at),
      select: {r, t}
    )
  end

  defp query(ids) do
    from(r in Rule,
      join: t in assoc(r, :rule_type),
      where: is_nil(r.deleted_at),
      where: r.id in ^ids,
      select: {r, t}
    )
  end

  defp preload({rule, rule_type}) do
    Map.put(rule, :rule_type, rule_type)
  end
end
