defmodule TdDd.Cache.StructureLoader do
  @moduledoc """
  Module to manage cache loading of data structure information.
  """

  @behaviour TdCache.EventStream.Consumer

  use GenServer

  alias TdCache.Redix
  alias TdCache.StructureCache
  alias TdDd.Cache.StructureEntry
  alias TdDd.DataStructures
  alias TdDd.DataStructures.RelationTypes
  alias TdDd.DataStructures.Search.Indexer

  require Logger

  ## Client API

  def start_link(config \\ []) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  def refresh(opts \\ []) do
    GenServer.cast(__MODULE__, {:refresh, opts})
  end

  ## EventStream.Consumer Callbacks

  @impl TdCache.EventStream.Consumer
  def consume(events) do
    GenServer.call(__MODULE__, {:consume, events})
  end

  ## GenServer callbacks

  @impl GenServer
  def init(_init_arg) do
    Logger.info("started")
    {:ok, %{}}
  end

  @impl GenServer
  def handle_cast({:refresh, opts}, state) do
    do_refresh(opts)
    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:consume, events}, _from, state) do
    structure_ids = Enum.flat_map(events, &read_structure_ids/1)
    reply = cache_structures(structure_ids)
    Indexer.reindex(structure_ids)
    {:reply, reply, state}
  end

  ## Private functions

  defp read_structure_ids(%{event: "add_link", source: source, target: target}) do
    [source, target]
    |> maybe_update_last_change_at()
    |> extract_structure_ids()
  end

  defp read_structure_ids(%{event: "remove_link", source: source, target: target}) do
    [source, target]
    |> maybe_update_last_change_at()
    |> extract_structure_ids()
  end

  defp read_structure_ids(%{event: "add_rule_implementation_link", structure_ids: structure_ids}) do
    structure_ids
    |> String.split(",")
    |> Enum.map(&String.to_integer/1)
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
    DataStructures.enriched_structure_versions(
      data_structure_ids: structure_ids,
      relation_type_id: RelationTypes.default_id!()
    )
    |> Enum.map(&StructureEntry.cache_entry/1)
    |> Enum.map(&StructureCache.put(&1, opts))
  end

  defp maybe_update_last_change_at(structure_keys) do
    structure_keys
    |> Enum.filter(&String.starts_with?(&1, "data_structure:"))
    |> Enum.uniq()
    |> Enum.each(&DataStructures.update_last_change_at([&1]))

    structure_keys
  end

  defp do_refresh(opts) do
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
    keep_ids = StructureCache.referenced_ids()
    remove_count = clean_cached_structures(keep_ids)
    updates = cache_structures(keep_ids, opts)

    update_count =
      Enum.count(updates, fn
        {:ok, ["OK" | _]} -> true
        _ -> false
      end)

    {update_count, remove_count}
  end

  defp clean_cached_structures(keep_ids) do
    keep_key = "_data_structure:keys:keep:#{System.os_time(:millisecond)}"

    ids_to_delete =
      ["SMEMBERS", "data_structure:keys"]
      |> Redix.command!()
      |> Enum.map(fn "data_structure:" <> id -> String.to_integer(id) end)
      |> Enum.reject(&(&1 in keep_ids))

    keep_cmds =
      keep_ids
      |> Enum.map(&"data_structure:#{&1}")
      |> Enum.chunk_every(1000)
      |> Enum.map(&["SADD", keep_key | &1])

    del_cmds =
      ids_to_delete
      |> Enum.flat_map(&["data_structure:#{&1}", "data_structure:#{&1}:path"])
      |> Enum.chunk_every(1000)
      |> Enum.map(&["DEL" | &1])

    [
      keep_cmds,
      del_cmds,
      [
        ["SINTERSTORE", "data_structure:keys", "data_structure:keys", keep_key],
        ["DEL", keep_key]
      ]
    ]
    |> Enum.concat()
    |> Redix.transaction_pipeline!()

    Enum.count(ids_to_delete)
  end
end
