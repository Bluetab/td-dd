defmodule TdDd.Cache.StructureLoader do
  @moduledoc """
  Module to manage cache loading of data structure information.
  """

  @behaviour TdCache.EventStream.Consumer

  use GenServer

  alias TdCache.StructureCache
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure

  require Logger

  ## Client API

  def start_link(config \\ []) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  ## EventStream.Consumer Callbacks

  @impl true
  def consume(events) do
    GenServer.call(__MODULE__, {:consume, events})
  end

  ## GenServer callbacks

  @impl true
  def init(state) do
    name = String.replace_prefix("#{__MODULE__}", "Elixir.", "")
    Logger.info("Running #{name}")
    {:ok, state}
  end

  @impl true
  def handle_call({:consume, events}, _from, state) do
    reply =
      events
      |> Enum.filter(&(Map.get(&1, :event) == "add_link"))
      |> Enum.flat_map(&[&1.source, &1.target])
      |> Enum.filter(&String.starts_with?(&1, "data_structure:"))
      |> Enum.uniq()
      |> Enum.map(&String.split(&1, ":"))
      |> Enum.flat_map(&tl(&1))
      |> Enum.map(&String.to_integer/1)
      |> Enum.map(&cache_data_structure/1)

    {:reply, reply, state}
  end

  ## Private functions

  defp cache_data_structure(id) do
    id
    |> DataStructures.get_data_structure!()
    |> to_cache_entry
    |> put_cache
  end

  defp to_cache_entry(%DataStructure{} = structure) do
    system =
      structure
      |> Map.get(:system, %{})
      |> Map.take([:id, :external_id, :name])

    structure
    |> Map.take([:id, :group, :name, :type, :metadata, :updated_at])
    |> Map.put(:system, system)
    |> Map.put(:path, DataStructures.get_latest_path(structure))
  end

  defp put_cache(entry) do
    StructureCache.put(entry)
  end
end
