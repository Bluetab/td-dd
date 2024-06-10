defmodule TdDq.Cache.RuleLoader do
  @moduledoc """
  GenServer to load rule entries into shared cache.
  """

  use GenServer

  alias TdCache.RuleCache
  alias TdDq.Implementations
  alias TdDq.Implementations.Search.Indexer, as: ImplementationsIndexer
  alias TdDq.Rules
  alias TdDq.Rules.Search.Indexer, as: RulesIndexer

  require Logger

  ## Client API

  def start_link(config \\ []) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  def refresh(rule_ids) when is_list(rule_ids) do
    GenServer.call(__MODULE__, {:refresh, rule_ids})
  end

  def refresh(rule_id) do
    refresh([rule_id])
  end

  def delete(rule_ids) when is_list(rule_ids) do
    GenServer.call(__MODULE__, {:delete, rule_ids})
  end

  def delete(rule_id) do
    delete([rule_id])
  end

  def ping(timeout \\ 5000) do
    GenServer.call(__MODULE__, :ping, timeout)
  end

  ## GenServer Callbacks

  @impl true
  def init(state) do
    name = String.replace_prefix("#{__MODULE__}", "Elixir.", "")
    Logger.info("Running #{name}")

    unless Application.get_env(:td_dd, :env) == :test do
      Process.send_after(self(), :clean, 0)
      Process.send_after(self(), :load, 0)
    end

    {:ok, state}
  end

  @impl true
  def handle_info(:load, state) do
    count =
      Rules.list_rules()
      |> Enum.map(&RuleCache.put/1)
      |> Enum.reject(&(&1 == {:ok, []}))
      |> Enum.count()

    case count do
      0 -> Logger.debug("RuleLoader: no rules changed")
      1 -> Logger.info("RuleLoader: put 1 rule")
      n -> Logger.info("RuleLoader: put #{n} rules")
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(:clean, state) do
    rule_ids =
      Rules.list_rules()
      |> Enum.map(&Integer.to_string(&1.id))
      |> MapSet.new()

    count =
      case RuleCache.keys() do
        {:ok, keys} ->
          keys
          |> MapSet.new(&String.replace_leading(&1, "rule:", ""))
          |> MapSet.difference(rule_ids)
          |> Enum.map(&RuleCache.delete/1)
          |> Enum.count()

        _ ->
          :error
      end

    case count do
      :error -> Logger.warn("RuleLoader: error reading keys from cache")
      0 -> Logger.debug("RuleLoader: no stale rules in cache")
      n -> Logger.info("RuleLoader: deleted #{n} stale rules from cache")
    end

    {:noreply, state}
  end

  @impl true
  def handle_call(:ping, _from, state) do
    {:reply, :pong, state}
  end

  @impl true
  def handle_call({:refresh, ids}, _from, state) do
    reply = cache_rules(ids)
    RulesIndexer.reindex(ids)

    ids
    |> Implementations.get_rule_implementations()
    |> Enum.map(&Map.get(&1, :id))
    |> then(&ImplementationsIndexer.reindex(&1))

    {:reply, reply, state}
  end

  @impl true
  def handle_call({:delete, ids}, _from, state) do
    delete_count =
      ids
      |> Enum.map(&RuleCache.delete/1)
      |> Enum.reject(&(&1 == {:ok, [0, 0]}))
      |> Enum.count()

    RulesIndexer.delete(ids)

    ids
    |> Implementations.get_rule_implementations()
    |> Enum.map(&Map.get(&1, :id))
    |> then(&ImplementationsIndexer.delete(&1))

    {:reply, delete_count, state}
  end

  ## Private functions

  defp cache_rules(ids) do
    ids
    |> Rules.list_rules()
    |> Enum.map(&RuleCache.put/1)
    |> Enum.reject(&(&1 == {:ok, []}))
    |> Enum.count()
  end
end
