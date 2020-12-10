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

  @index_worker Application.compile_env(:td_dd, :index_worker)

  ## Client API

  def start_link(config \\ []) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  def refresh do
    GenServer.cast(__MODULE__, :refresh)
  end

  ## EventStream.Consumer Callbacks

  @impl TdCache.EventStream.Consumer
  def consume(events) do
    GenServer.call(__MODULE__, {:consume, events})
  end

  ## GenServer callbacks

  @impl GenServer
  def init(config) do
    name = String.replace_prefix("#{__MODULE__}", "Elixir.", "")
    Logger.info("Running #{name}")

    unless Application.get_env(:td_dd, :env) == :test do
      Process.send_after(self(), :migrate, 0)
    end

    {:ok, config}
  end

  @impl GenServer
  def handle_info(:migrate, state) do
    if Redix.acquire_lock?("TdDd.Structures.Migrations:TD-3066") do
      # Force cache refresh to populate set of deleted referenced structures
      do_refresh(force: true)
    end

    {:noreply, state}
  end

  @impl GenServer
  def handle_cast(:refresh, state) do
    do_refresh()
    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:consume, events}, _from, state) do
    structure_ids = Enum.flat_map(events, &read_structure_ids/1)
    reply = cache_structures(structure_ids)
    @index_worker.reindex(structure_ids)
    {:reply, reply, state}
  end

  ## Private functions

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

  def cache_structures(structure_ids, opts \\ []) do
    structure_ids
    |> Enum.map(&DataStructures.get_latest_version(&1, [:parents]))
    |> Enum.filter(& &1)
    |> Enum.map(&to_cache_entry/1)
    |> Enum.map(&StructureCache.put(&1, opts))
  end

  defp to_cache_entry(%DataStructureVersion{data_structure_id: id, data_structure: ds} = dsv) do
    %{external_id: external_id, system_id: system_id} = ds

    dsv
    |> Map.take([:group, :name, :type, :metadata, :updated_at, :deleted_at])
    |> Map.put(:id, id)
    |> Map.put(:path, DataStructures.get_path(dsv))
    |> Map.put(:external_id, external_id)
    |> Map.put(:system_id, system_id)
    |> Map.put(:parent_id, get_first_parent_id(dsv))
  end

  defp get_first_parent_id(dsv) do
    case dsv.parents do
      nil -> nil
      [] -> nil
      [parent_dsv | _o] -> parent_dsv.data_structure_id
    end
  end

  defp do_refresh(opts \\ []) do
    Timer.time(
      fn -> refresh_cached_structures(opts) end,
      fn ms, {updated, removed} ->
        Logger.info(
          "Structure cache refreshed in #{ms}ms (updated=#{updated}, removed=#{removed})"
        )
      end
    )
  rescue
    e -> Logger.error("Unexpected error while refreshing cached structures... #{inspect(e)}")
  end

  defp refresh_cached_structures(opts) do
    with [_ | _] = keep_ids <- StructureCache.referenced_ids(),
         remove_count <- clean_cached_structures(keep_ids),
         updates <- cache_structures(keep_ids, opts),
         update_count <-
           Enum.count(updates, fn
             {:ok, ["OK" | _]} -> true
             _ -> false
           end) do
      {update_count, remove_count}
    end
  end

  defp clean_cached_structures(keep_ids) do
    ids_to_delete =
      ["SMEMBERS", "data_structure:keys"]
      |> Redix.command!()
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
      ["SINTERSTORE", "data_structure:keys", "data_structure:keys", "data_structure:keys:keep"]
    ])
    |> Redix.transaction_pipeline!()

    Enum.count(ids_to_delete)
  end
end
