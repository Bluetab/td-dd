defmodule TdDq.Cache.RuleLoader do
  @moduledoc """
  GenServer to load rule entries into shared cache.
  """

  use GenServer

  alias TdCache.RuleCache
  alias TdDq.Rules

  require Logger

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

  @impl true
  def init(state) do
    name = String.replace_prefix("#{__MODULE__}", "Elixir.", "")
    Logger.info("Running #{name}")

    unless Application.get_env(:td_dq, :env) == :test do
      Process.send_after(self(), :load, 0)
      Process.send_after(self(), :clean, 0)
    end

    {:ok, state}
  end

  @impl true
  def handle_info(:load, state) do
    count =
      Rules.list_rules()
      |> Enum.filter(&(not is_nil(&1.business_concept_id)))
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
    {:ok, cached_ids} = RuleCache.read_rule_keys()

    rule_ids = 
      Rules.list_rules()
      |> Enum.map(& &1.id)
      |> MapSet.new()

    count =
      cached_ids
      |> Enum.map(&String.split(&1, ":"))
      |> Enum.map(fn [_, id] -> id end)
      |> Enum.map(&String.to_integer/1)
      |> MapSet.new()
      |> MapSet.difference(rule_ids)
      |> MapSet.to_list()
      |> Enum.map(&RuleCache.delete/1)
      |> Enum.reject(&(&1 == {:ok, [0, 0]}))
      |> Enum.count()
      
    case count do
      0 -> Logger.debug("RuleLoader: no deleted rules")
      n -> Logger.info("RuleLoader: put #{n} rules")
    end

    {:noreply, state}
  end

  @impl true
  def handle_call({:refresh, ids}, _from, state) do
    reply = cache_rules(ids)
    {:reply, reply, state}
  end

  @impl true
  def handle_call({:delete, ids}, _from, state) do
    delete_count =
      ids
      |> Enum.map(&RuleCache.delete/1)
      |> Enum.reject(&(&1 == {:ok, [0, 0]}))
      |> Enum.count()

    {:reply, delete_count, state}
  end

  def cache_rules(ids) do
    ids
    |> Rules.list_rules()
    |> Enum.filter(&(not is_nil(&1.business_concept_id)))
    |> Enum.map(&RuleCache.put/1)
    |> Enum.reject(&(&1 == {:ok, []}))
    |> Enum.count()
  end
end
