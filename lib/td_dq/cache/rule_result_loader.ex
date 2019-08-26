defmodule TdDq.Cache.RuleResultLoader do
  @moduledoc """
  GenServer to load rule results into shared cache.
  """

  use GenServer
  alias TdCache.RuleResultCache
  alias TdDq.Rules

  require Logger

  def start_link(config \\ []) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  def failed(rule_result_ids) when is_list(rule_result_ids) do
    GenServer.call(__MODULE__, {:failed, rule_result_ids})
  end

  def failed(rule_result_ids) do
    failed([rule_result_ids])
  end

  @impl true
  def init(state) do
    name = String.replace_prefix("#{__MODULE__}", "Elixir.", "")
    Logger.info("Running #{name}")
    {:ok, state}
  end

  @impl true
  def handle_call({:failed, ids}, _from, state) do
    cached = cache_results(ids)
    failed_ids = update_failed_ids(ids)
    {:reply, [cached, failed_ids], state}
  end

  defp cache_results(ids) do
    ids
    |> Rules.list_rule_results()
    |> Enum.map(&RuleResultCache.put/1)
    |> Enum.reject(&(&1 == {:ok, []}))
    |> Enum.count()
  end

  defp update_failed_ids(ids) do
    {:ok, count} = RuleResultCache.update_failed_ids(ids)
    count
  end
end
