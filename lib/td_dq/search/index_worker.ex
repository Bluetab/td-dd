defmodule TdDq.Search.IndexWorker do
  @moduledoc """
  GenServer to run reindex task
  """

  @behaviour TdCache.EventStream.Consumer

  use GenServer

  alias TdDq.Rules
  alias TdDq.Rules.Implementations
  alias TdDq.Search.Indexer

  require Logger

  ## Client API

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def reindex do
    GenServer.cast(__MODULE__, :reindex)
  end

  def reindex_implementations(:all) do
    GenServer.cast(__MODULE__, {:reindex_implementations, :all})
  end

  def reindex_implementations(ids) when is_list(ids) do
    GenServer.call(__MODULE__, {:reindex_implementations, ids})
  end

  def reindex_implementations(id) do
    reindex_implementations([id])
  end

  def reindex_rules(:all) do
    GenServer.cast(__MODULE__, {:reindex_rules, :all})
  end

  def reindex_rules(ids) when is_list(ids) do
    GenServer.call(__MODULE__, {:reindex_rules, ids})
  end

  def reindex_rules(id) do
    reindex_rules([id])
  end

  def delete_rules(ids) when is_list(ids) do
    GenServer.call(__MODULE__, {:delete_rules, ids})
  end

  def delete_rules(id) do
    delete_rules([id])
  end

  def delete_implementations(ids) when is_list(ids) do
    GenServer.call(__MODULE__, {:delete_implementations, ids})
  end

  def delete_implementations(id) do
    delete_implementations([id])
  end

  def ping(timeout \\ 5000) do
    GenServer.call(__MODULE__, :ping, timeout)
  end

  ## EventStream.Consumer Callbacks

  @impl TdCache.EventStream.Consumer
  def consume(events) do
    GenServer.cast(__MODULE__, {:consume, events})
  end

  ## GenServer Callbacks

  @impl GenServer
  def init(state) do
    name = String.replace_prefix("#{__MODULE__}", "Elixir.", "")
    Logger.info("Running #{name}")
    {:ok, state}
  end

  @impl GenServer
  def handle_cast(:reindex, state) do
    do_reindex()
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:reindex_rules, :all}, state) do
    do_reindex_rules(:all)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:reindex_implementations, :all}, state) do
    do_reindex_implementations(:all)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:consume, events}, state) do
    rule_ids =
      events
      |> Enum.flat_map(&read_rule_ids/1)
      |> Enum.uniq()

    if Enum.member?(rule_ids, :all) do
      do_reindex()
    else
      do_reindex_rules(rule_ids)

      rule_ids
      |> Implementations.get_rule_implementations()
      |> Enum.map(&Map.get(&1, :id))
      |> do_reindex_implementations()
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:reindex_rules, ids}, _from, state) do
    reply = do_reindex_rules(ids)
    {:reply, reply, state}
  end

  @impl GenServer
  def handle_call({:reindex_implementations, ids}, _from, state) do
    reply = do_reindex_implementations(ids)
    {:reply, reply, state}
  end

  @impl GenServer
  def handle_call(:ping, _from, state) do
    {:reply, :pong, state}
  end

  @impl GenServer
  def handle_call({:delete_rules, ids}, _from, state) do
    reply =
      Timer.time(
        fn -> Indexer.delete_rules(ids) end,
        fn millis, _ -> Logger.info("Rules deleted in #{millis}ms") end
      )

    {:reply, reply, state}
  end

  @impl GenServer
  def handle_call({:delete_implementations, ids}, _from, state) do
    reply =
      Timer.time(
        fn -> Indexer.delete_implementations(ids) end,
        fn millis, _ -> Logger.info("Implementations deleted in #{millis}ms") end
      )

    {:reply, reply, state}
  end

  ## Private functions
  defp do_reindex do
    do_reindex_rules(:all)
    do_reindex_implementations(:all)
  end

  defp do_reindex_rules([]), do: :ok

  defp do_reindex_rules(ids) do
    Timer.time(
      fn -> Indexer.reindex_rules(ids) end,
      fn millis, _ -> Logger.info("Rules indexed in #{millis}ms") end
    )
  end

  defp do_reindex_implementations([]), do: :ok

  defp do_reindex_implementations(ids) do
    Timer.time(
      fn -> Indexer.reindex_implementations(ids) end,
      fn millis, _ -> Logger.info("Implementations indexed in #{millis}ms") end
    )
  end

  defp read_rule_ids(%{event: "concept_updated", resource_id: business_concept_id}) do
    %{"business_concept_id" => business_concept_id}
    |> Rules.list_rules()
    |> Enum.map(& &1.id)
  end

  defp read_rule_ids(%{event: "confidential_concepts"}) do
    Rules.list_rules_with_bc_id()
    |> Enum.map(& &1.id)
  end

  defp read_rule_ids(%{event: "template_updated", scope: "dq"}), do: [:all]

  defp read_rule_ids(_), do: []
end
