defmodule TdDd.Cache.SystemLoader do
  @moduledoc """
  Module to manage cache loading of system information.
  """

  use GenServer

  alias TdCache.SystemCache
  alias TdDd.Systems

  require Logger

  ## Client API

  def start_link(config \\ []) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  def refresh(system_ids) when is_list(system_ids) do
    GenServer.call(__MODULE__, {:refresh, system_ids})
  end

  def refresh(system_id) do
    refresh([system_id])
  end

  def delete(system_id) do
    GenServer.call(__MODULE__, {:delete, system_id})
  end

  ## GenServer callbacks

  @impl true
  def init(state) do
    name = String.replace_prefix("#{__MODULE__}", "Elixir.", "")
    Logger.info("Running #{name}")

    unless Application.get_env(:td_dd, :env) == :test do
      Process.send_after(self(), :load_cache, 0)
    end

    {:ok, state}
  end

  @impl true
  def handle_info(:load_cache, state) do
    load_all_systems()

    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:refresh, ids}, _from, state) do
    reply =
      ids
      |> Enum.map(&Systems.get_system/1)
      |> Enum.filter(&(elem(&1, 0) == :ok))
      |> Enum.map(&elem(&1, 1))
      |> load_system_data()

    {:reply, reply, state}
  end

  @impl GenServer
  def handle_call({:delete, id}, _from, state) do
    reply = SystemCache.delete(id)
    {:reply, reply, state}
  end

  ## Private functions

  defp load_all_systems do
    Systems.list_systems()
    |> load_system_data()
  end

  def load_system_data(systems) do
    results =
      systems
      |> Enum.map(&Map.take(&1, [:id, :external_id, :name]))
      |> Enum.map(&SystemCache.put/1)
      |> Enum.map(fn {res, _} -> res end)

    if Enum.any?(results, &(&1 != :ok)) do
      Logger.warning("Cache loading failed")
    else
      Logger.info("Cached #{length(results)} systems")
    end
  end
end
