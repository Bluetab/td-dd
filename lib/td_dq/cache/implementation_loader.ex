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

  def implementation_to_migrate(opts \\ []) do
    GenServer.cast(__MODULE__, {:implementation_to_migrate, opts})
  end

  @doc """
  Updates implementation cache if it has links. Should be called using
  `Ecto.Multi.run/5`.
  """
  def maybe_update_implementation_cache(_repo, %{implementations_moved: {_, implementations}}) do
    implementation_ref_to_cache =
      implementations
      |> Enum.map(fn  %Implementation{implementation_ref: implementation_ref} = implementation ->
        ##
        case Implementations.get_implementation_links(implementation) do
          [] -> nil
          _ -> implementation_ref
        end
      end)
      |> Enum.filter(fn implementation_ref -> implementation_ref != nil end)
    IO.inspect(label: "maybeupdate implementatio ->")
    {:ok, cache_implementations(implementation_ref_to_cache, force: true)}
  end

  def maybe_update_implementation_cache(_repo, %{implementation: %{implementation_ref: implementation_ref}}) do
    maybe_update_implementation_cache(implementation_ref)
  end

  def maybe_update_implementation_cache(implementation_ref) do
    # IO.inspect(implementation_ref, label: "maybe update cache imp_ref ->")

    case Implementations.get_implementation_links(%Implementation{implementation_ref: implementation_ref}) do
      [] -> {:ok, nil}
      links ->
      IO.inspect(links, label: "I have links --->")
      {:ok, cache_implementations([implementation_ref], force: true)}
    end
  end

  def cache_map_implementation_id_to_implementation_ref do
    ### TODO TD-5140 refactor this code
    ImplementationCache.referenced_ids()
    # |> IO.inspect(label: "referenced_ids")
    |> Implementations.get_implementations_ref()
    |> ImplementationCache.put_relation_impl_id_and_impl_ref()
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

  def handle_cast({:implementation_to_migrate, _opts}, state) do
    ImplementationCache.delete_relation_impl_id_and_impl_ref()
    # |> IO.inspect(label: "delete relation ->")
    cache_map_implementation_id_to_implementation_ref()
    # |> IO.inspect(label: "handel cast imop ->")
    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:consume, events}, _from, state) do
    implementation_ids = Enum.flat_map(events, &read_implementation_ids/1)
    |> IO.inspect(label: "consume read imp ->")
    ## TODO TD-5140 revisar esta parte del código
    reply = cache_implementations(implementation_ids)
    {:reply, reply, state}
  end

  ## Private functions

  defp read_implementation_ids(%{event: "add_link", source: source, target: target}) do
    IO.inspect(source, label: " read imp ids source ->")
    extract_implementation_ids([source, target])
  end

  defp read_implementation_ids(%{event: "remove_link", source: source, target: target}) do
    extract_implementation_ids([source, target])
  end

  # unsupported events...
  defp read_implementation_ids(_), do: []

  defp extract_implementation_ids(implementation_keys) do
    implementation_keys
    |> IO.inspect(label: "implementations keys --->")
    |> Enum.filter(&String.starts_with?(&1, "implementation_ref:"))
    |> Enum.uniq()
    |> Enum.map(fn "implementation_ref:" <> id -> id end)
    |> Enum.map(&String.to_integer/1)
  end

  def cache_implementations(implementation_refs, opts \\ []) do
    ## la modifiacion para obtener el publicado o la ultima version con cada uno de los ids.
    implementation_refs
    |> IO.inspect(label: "implementation refs --->")
    |> Enum.map(&get_linked_implementation/1)
    |> IO.inspect(label: "linked implementations ->")
    |> Enum.map(&ImplementationCache.put(&1, opts))
  end

  defp get_linked_implementation(implementation_ref) do
    %{id: implementation_id} = implementation = Implementations.get_linked_implementation!(implementation_ref, preload: [:rule])

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
    ## TODO: TD-5140 revisar
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
