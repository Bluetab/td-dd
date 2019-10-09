defmodule TdDq.Search.IndexWorker do
  @moduledoc """
  GenServer to run reindex task
  """

  @behaviour TdCache.EventStream.Consumer

  use GenServer

  alias TdDq.Rules
  alias TdDq.Search.Indexer

  require Logger

  ## Client API

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def reindex(:all) do
    GenServer.cast(__MODULE__, {:reindex, :all})
  end

  def reindex(ids) when is_list(ids) do
    GenServer.call(__MODULE__, {:reindex, ids})
  end

  def reindex(id) do
    reindex([id])
  end

  def delete(ids) when is_list(ids) do
    GenServer.call(__MODULE__, {:delete, ids})
  end

  def delete(id) do
    delete([id])
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

    unless Application.get_env(:td_dq, :env) == :test do
      Process.send_after(self(), :migrate, 0)
    end

    {:ok, state}
  end

  @impl GenServer
  def handle_info(:migrate, state) do
    Indexer.migrate()
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:reindex, :all}, state) do
    do_reindex(:all)
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:consume, events}, state) do
    ids =
      events
      |> Enum.flat_map(&read_rule_ids/1)
      |> Enum.uniq()

    if Enum.member?(ids, :all) do
      do_reindex(:all)
    else
      do_reindex(ids)
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:ping, _from, state) do
    {:reply, :pong, state}
  end

  @impl GenServer
  def handle_call({:reindex, ids}, _from, state) do
    reply = do_reindex(ids)
    {:reply, reply, state}
  end

  @impl GenServer
  def handle_call({:delete, ids}, _from, state) do
    reply =
      Timer.time(
        fn -> Indexer.delete(ids) end,
        fn millis, _ -> Logger.info("Rules deleted in #{millis}ms") end
      )

    {:reply, reply, state}
  end

  ## Private functions

  defp do_reindex([]), do: :ok

  defp do_reindex(ids) do
    Timer.time(
      fn -> Indexer.reindex(ids) end,
      fn millis, _ -> Logger.info("Rules indexed in #{millis}ms") end
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

  defp read_rule_ids(%{event: "add_template", scope: "dq"}), do: [:all]

  defp read_rule_ids(_), do: []
end
