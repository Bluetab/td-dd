defmodule TdDq.Cache.ImplementationLoader do
  @moduledoc """
  Module to manage cache loading of implementation information.
  """

  @behaviour TdCache.EventStream.Consumer

  use GenServer

  alias TdCache.ImplementationCache
  alias TdDq.Events.QualityEvents
  alias TdDq.Implementations
  alias TdDq.Implementations.Implementation

  require Logger

  ## Client API

  def start_link(config \\ []) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  def refresh(opts \\ []) do
    GenServer.cast(__MODULE__, {:refresh, opts})
  end

  @doc """
  Updates implementation cache if it has links. Should be called using
  `Ecto.Multi.run/5`.
  """
  def maybe_update_implementation_cache(_repo, %{implementation: %{id: implementation_id}}) do
    maybe_update_implementation_cache(implementation_id)
  end

  def maybe_update_implementation_cache(implementation_id) do
    case Implementations.get_implementation_links(%Implementation{id: implementation_id}) do
      [] -> {:ok, nil}
      _ -> {:ok, cache_implementations([implementation_id], force: true)}
    end
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
    implementation_ids = Enum.flat_map(events, &read_implementation_ids/1)
    reply = cache_implementations(implementation_ids)
    {:reply, reply, state}
  end

  ## Private functions

  defp read_implementation_ids(%{event: "add_link", source: source, target: target}) do
    extract_implementation_ids([source, target])
  end

  defp read_implementation_ids(%{event: "remove_link", source: source, target: target}) do
    extract_implementation_ids([source, target])
  end

  # defp read_implementation_ids(%{event: "add_rule_implementation_link", structure_ids: structure_ids}) do
  #   structure_ids
  #   |> String.split(",")
  #   |> Enum.map(&String.to_integer/1)
  # end

  # defp read_implementation_ids(%{event: "add_rule_implementation_link", structure_id: structure_id}) do
  #   [structure_id]
  # end

  # unsupported events...
  defp read_implementation_ids(_), do: []

  defp extract_implementation_ids(implementation_keys) do
    implementation_keys
    |> Enum.filter(&String.starts_with?(&1, "implementation:"))
    |> Enum.uniq()
    |> Enum.map(fn "implementation:" <> id -> id end)
    |> Enum.map(&String.to_integer/1)
  end

  def cache_implementations(implementation_ids, opts \\ []) do
    implementation_ids
    |> Enum.map(&get_implementation/1)
    |> Enum.map(&ImplementationCache.put(&1, opts))
  end

  defp get_implementation(implementation_id) do
    implementation = Implementations.get_implementation!(implementation_id, preload: [:rule])

    quality_event = QualityEvents.get_event_by_imp(implementation_id)

    execution_result_info =
      Implementation.get_execution_result_info(implementation, quality_event)

    Map.put(implementation, :execution_result_info, execution_result_info)
  end

  defp do_refresh(opts) do
    Timer.time(
      fn -> refresh_cached_implementation(opts) end,
      fn ms, {updated, removed} ->
        Logger.info(
          "Implementation cache refreshed in #{ms}ms (updated=#{updated}, removed=#{removed})"
        )
      end
    )
  rescue
    e -> Logger.error("Unexpected error while refreshing cached implementations.. #{inspect(e)}")
  end

  defp refresh_cached_implementation(opts) do
    keep_ids = ImplementationCache.referenced_ids()
    remove_count = ImplementationCache.clean_cached_implementations(keep_ids)
    updates = cache_implementations(keep_ids, opts)

    update_count =
      Enum.count(updates, fn
        {:ok, ["OK" | _]} -> true
        _ -> false
      end)

    {update_count, remove_count}
  end
end
