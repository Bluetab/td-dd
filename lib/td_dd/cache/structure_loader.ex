defmodule TdDd.Cache.StructureLoader do
  @moduledoc """
  Module to manage cache loading of data structure information.
  """

  @behaviour TdCache.EventStream.Consumer

  use GenServer

  alias TdCache.Redix
  alias TdCache.StructureCache
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructureVersion

  require Logger

  @index_worker Application.get_env(:td_dd, :index_worker)
  @structure_metadata_migration_key "TdDd.DataStructures.Migrations:td-2979"

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

    unless Application.get_env(:td_dd, :env) == :test do
      Process.send_after(self(), :refresh_cached_structures, 0)
    end

    {:ok, state}
  end

  @impl true
  def handle_info(:refresh_cached_structures, state) do
    try do
      if Redix.exists?(@structure_metadata_migration_key) == false do
        Timer.time(
          fn -> refresh_cached_structures() end,
          fn ms, _ -> Logger.info("Structure cache refreshed in #{ms}ms") end
        )

        Redix.command!(["SET", @structure_metadata_migration_key, "#{DateTime.utc_now()}"])
      end
    rescue
      e -> Logger.error("Unexpected error while refreshing cached structures... #{inspect(e)}")
    end

    {:noreply, state}
  end

  @impl true
  def handle_call({:consume, events}, _from, state) do
    structure_ids = Enum.flat_map(events, &read_structure_ids/1)
    reply = cache_structures(structure_ids)
    @index_worker.reindex(structure_ids)
    {:reply, reply, state}
  end

  defp read_structure_ids(%{event: "add_link", source: source, target: target}) do
    extract_structure_ids([source, target])
  end

  defp read_structure_ids(%{event: "remove_link", source: source, target: target}) do
    extract_structure_ids([source, target])
  end

  defp read_structure_ids(%{event: "add_rule_implementation_link", structure_id: structure_id}) do
    [structure_id]
  end

  # unsupported events...
  defp read_structure_ids(_), do: []

  defp extract_structure_ids(structure_keys) do
    structure_keys
    |> Enum.filter(&String.starts_with?(&1, "data_structure:"))
    |> Enum.uniq()
    |> Enum.map(fn "data_structure:" <> id -> id end)
    |> Enum.map(&String.to_integer/1)
  end

  ## Private functions

  defp cache_structures(structure_ids, opts \\ []) do
    structure_ids
    |> Enum.map(&DataStructures.get_latest_version(&1, [:system, :parents]))
    |> Enum.filter(& &1)
    |> Enum.map(&to_cache_entry/1)
    |> Enum.map(&put_cache(&1, opts))
  end

  defp to_cache_entry(%DataStructureVersion{data_structure_id: id, data_structure: ds} = dsv) do
    system =
      dsv
      |> Map.get(:system, %{})
      |> Map.take([:id, :external_id, :name])

    dsv
    |> Map.take([:group, :name, :type, :metadata, :updated_at, :deleted_at])
    |> Map.put(:id, id)
    |> Map.put(:system, system)
    |> Map.put(:path, DataStructures.get_path(dsv))
    |> Map.put(:external_id, Map.get(ds, :external_id))
    |> Map.put(:parent_id, get_first_parent_id(dsv))
  end

  defp get_first_parent_id(dsv) do
    case dsv.parents do
      nil -> nil
      [] -> nil
      [parent_dsv | _o] -> parent_dsv.data_structure_id
    end
  end

  defp put_cache(entry, opts) do
    StructureCache.put(entry, opts)
  end

  defp refresh_cached_structures do
    with [_ | _] = keep_ids <- read_referenced_structure_ids(),
         count <- clean_cached_structures(keep_ids) do
      Logger.info("Removed #{count} structures from cache")
    end
  end

  defp clean_cached_structures(keep_ids) do
    ids_to_delete =
      Redix.command!(["SMEMBERS", "data_structure:keys"])
      |> Enum.map(fn "data_structure:" <> id -> String.to_integer(id) end)
      |> Enum.reject(&(&1 in keep_ids))

    keep_ids
    |> Enum.map(&"data_structure:#{&1}")
    |> Enum.chunk_every(1000)
    |> Enum.map(&["SADD", "data_structure:keys:keep" | &1])
    |> Redix.transaction_pipeline!()

    ids_to_delete
    |> Enum.flat_map(&["data_structure:#{&1}", "data_structure:#{&1}:path"])
    |> Enum.chunk_every(1000)
    |> Enum.map(&["DEL" | &1])
    |> Enum.concat([
      ["SINTERSTORE", "data_structures:keys", "data_structures:keys", "data_structures:keys:keep"]
    ])
    |> Redix.transaction_pipeline!()
    |> Enum.sum()
  end

  defp read_referenced_structure_ids do
    alias TdCache.Redix.Stream

    {:ok, events} = Stream.read(:redix, "data_structure:events", transform: true)

    rule_structure_ids =
      events
      |> Enum.flat_map(fn
        %{event: "add_rule_implementation_link", structure_id: id} -> [id]
        _ -> []
      end)
      |> Enum.uniq()
      |> Enum.map(&String.to_integer/1)

    linked_structure_ids =
      Redix.command!(["SMEMBERS", "link:keys"])
      |> Enum.map(&Redix.read_map!/1)
      |> Enum.flat_map(fn %{source: source, target: target} -> [source, target] end)
      |> Enum.filter(&String.starts_with?(&1, "data_structure:"))
      |> Enum.map(fn "data_structure:" <> id -> id end)
      |> Enum.map(&String.to_integer/1)
      |> Enum.uniq()

    Enum.uniq(rule_structure_ids ++ linked_structure_ids)
  end
end
