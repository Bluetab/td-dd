defmodule TdDq.Cache.RuleIndexer do
  @moduledoc """
  GenServer to index information related to business concepts.
  """

  @behaviour TdCache.EventStream.Consumer

  use GenServer

  require Logger

  alias TdDq.Rules
  alias TdDq.Search.IndexWorker

  ## Client API

  def start_link(config \\ []) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  ## EventStream.Consumer Callbacks

  @impl true
  def consume(events) do
    GenServer.call(__MODULE__, {:consume, events})
  end

  ## GenServer Callbacks

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call({:consume, events}, _from, state) do
    reply =
      events
      |> Enum.map(&process/1)
      |> Enum.filter(&(&1 == :ok))
      |> Enum.count()

    {:reply, reply, state}
  end

  ## Private functions
  defp process(%{event: "concept_updated", resource_id: resource_id}) do
    %{"business_concept_id" => resource_id}
    |> Rules.list_rules()
    |> Enum.map(&Map.get(&1, :id))
    |> IndexWorker.reindex()
  end

  defp process(%{event: "confidential_concepts"}) do
    Rules.list_rules_with_bc_id()
    |> Enum.map(&Map.get(&1, :id))
    |> IndexWorker.reindex()
  end

  defp process(_), do: :ok
end
