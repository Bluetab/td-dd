defmodule TdCx.Cache.SourcesLatestEvent do
  @moduledoc """
  Sources latest event local cache
  """

  use GenServer

  require Logger

  alias TdCx.Sources

  ## Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def refresh(source_id, latest_event) do
    GenServer.call(__MODULE__, {:refresh, source_id, latest_event})
  end

  def delete(source_id) do
    GenServer.call(__MODULE__, {:delete, source_id})
  end

  def get(source_id) do
    GenServer.call(__MODULE__, {:get, source_id})
  end

  def state do
    GenServer.call(__MODULE__, :state)
  end

  ## GenServer callbacks

  @impl true
  def init(_opts) do
    name = String.replace_prefix("#{__MODULE__}", "Elixir.", "")
    Logger.info("Running #{name}")

    state = Sources.list_sources_with_latest_event()

    {:ok, state}
  end

  @impl true
  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:get, source_id}, _from, state) do
    {:reply, state[source_id], state}
  end

  @impl GenServer
  def handle_call({:refresh, source_id, latest_event}, _from, state) do
    new_state = Map.put(state, source_id, latest_event)
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:delete, source_id}, _from, state) do
    new_state = Map.delete(state, source_id)
    reply = if Map.has_key?(state, source_id), do: :deleted, else: :unchanged_no_key
    {:reply, {:ok, reply}, new_state}
  end
end
