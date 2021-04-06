defmodule TdCx.Cache.SourceLoader do
  @moduledoc """
  Module to manage cache loading of source information.
  """

  use GenServer

  alias TdCache.SourceCache
  alias TdCx.Sources

  require Logger

  ## Client API

  def start_link(config \\ []) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  def refresh(source_ids) when is_list(source_ids) do
    GenServer.call(__MODULE__, {:refresh, source_ids})
  end

  def refresh(source_id) do
    refresh([source_id])
  end

  def delete(source_id) do
    GenServer.call(__MODULE__, {:delete, source_id})
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
    refresh_all_sources()

    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:refresh, ids}, _from, state) do
    reply =
      ids
      |> Enum.map(&Sources.get_source!/1)
      |> load_source_data()

    {:reply, reply, state}
  end

  @impl GenServer
  def handle_call({:delete, id}, _from, state) do
    reply = SourceCache.delete(id)
    {:reply, reply, state}
  end

  ## Private functions

  defp refresh_all_sources do
    with sources <- Sources.list_sources(deleted: false),
         {:ok, cached_sources} <- SourceCache.sources(),
         ids_to_delete <- sources_to_delete(sources, cached_sources) do
      load_source_data(sources)
      delete_source_data(ids_to_delete)
    end
  end

  defp load_source_data(sources) do
    results =
      sources
      |> Enum.map(&Map.take(&1, [:id, :external_id, :config, :type]))
      |> Enum.map(&SourceCache.put/1)
      |> Enum.map(fn {res, _} -> res end)

    if Enum.any?(results, &(&1 != :ok)) do
      Logger.warn("Cache loading failed")
    else
      Logger.info("Cached #{length(results)} sources")
    end
  end

  defp sources_to_delete(sources, cached_sources) do
    sources = Enum.map(sources, &Map.get(&1, :id))

    cached_sources
    |> MapSet.new()
    |> MapSet.difference(MapSet.new(sources))
    |> MapSet.to_list()
  end

  defp delete_source_data(sources) do
    results =
      sources
      |> Enum.map(&SourceCache.delete/1)
      |> Enum.map(fn {res, _} -> res end)

    if Enum.any?(results, &(&1 != :ok)) do
      Logger.warn("Cache loading failed")
    else
      Logger.info("Deleted cached #{length(results)} sources")
    end
  end
end
