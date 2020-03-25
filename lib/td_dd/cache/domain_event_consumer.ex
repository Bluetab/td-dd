defmodule TdDd.Cache.DomainEventConsumer do
  @moduledoc """
  Module to dispatch actions when domain-related events are received.
  """

  @behaviour TdCache.EventStream.Consumer

  use GenServer

  alias TdDd.DataStructures
  alias TdDd.Search.IndexWorker

  require Logger

  ## Client API

  def start_link(config \\ []) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  ## EventStream.Consumer Callbacks

  @impl true
  def consume(events) do
    GenServer.cast(__MODULE__, {:consume, events})
  end

  ## GenServer callbacks

  @impl true
  def init(state) do
    name = String.replace_prefix("#{__MODULE__}", "Elixir.", "")
    Logger.info("Running #{name}")

    {:ok, state}
  end

  @impl true
  def handle_cast({:consume, events}, state) do
    events
    |> read_structure_ids()
    |> IndexWorker.reindex()

    {:noreply, state}
  end

  defp read_structure_ids(events) do
    case read_domain_ids(events) do
      [] ->
        []

      domain_ids ->
        %{domain_id: domain_ids}
        |> DataStructures.list_data_structures()
        |> Enum.map(& &1.id)
    end
  end

  defp read_domain_ids(events) do
    events
    |> Enum.flat_map(&read_domain_id/1)
    |> Enum.uniq()
  end

  defp read_domain_id(%{event: "domain_updated", domain: "domain:" <> domain_id}) do
    [String.to_integer(domain_id)]
  end

  defp read_domain_id(_), do: []
end
