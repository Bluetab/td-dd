defmodule TdDq.Cache.ImplementationLoader do
  @moduledoc """
  Module to manage cache loading of implementation information.
  """

  @behaviour TdCache.EventStream.Consumer

  use GenServer

  alias TdCache.ImplementationCache
  alias TdCache.LinkCache
  alias TdDq.Events.QualityEvents
  alias TdDq.Implementations
  alias TdDq.Implementations.Implementation
  alias TdDq.Implementations.Search.Indexer
  alias TdDq.Rules.RuleResults

  require Logger

  ## Client API

  def start_link(config \\ []) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  def refresh(opts \\ []) do
    GenServer.cast(__MODULE__, {:refresh, opts})
  end

  def implementation_ids_to_migrate_implementation_ref(opts \\ []) do
    GenServer.cast(__MODULE__, {:implementation_ids_to_migrate_implementation_ref, opts})
  end

  @doc """
  Updates implementation cache if it has links. Should be called using
  `Ecto.Multi.run/5`.
  """
  def maybe_update_implementation_cache(_repo, %{implementations_moved: {_, implementations}}),
    do: maybe_update_implementations_cache(implementations)

  def maybe_update_implementation_cache(_repo, %{
        update_implementations_domain: {_, implementations}
      }) do
    maybe_update_implementations_cache(implementations)
  end

  def maybe_update_implementation_cache(_repo, %{implementations: {_, implementations}}),
    do: maybe_update_implementations_cache(implementations)

  def maybe_update_implementation_cache(_repo, %{
        implementation: %{implementation_ref: implementation_ref}
      }) do
    maybe_update_implementation_cache(implementation_ref)
  end

  def maybe_update_implementation_cache(implementations) when is_list(implementations) do
    implementations
    |> Enum.map(fn %{implementation_ref: implementation_ref} = implementation ->
      case Implementations.get_implementation_links(implementation) do
        [] -> nil
        _ -> implementation_ref
      end
    end)
    |> Enum.filter(& &1)
    |> case do
      [] -> nil
      implementation_refs -> cache_implementations(implementation_refs, force: true)
    end
    |> then(&{:ok, &1})
  end

  def maybe_update_implementation_cache(implementation_ref) do
    case Implementations.get_implementation_links(%Implementation{
           implementation_ref: implementation_ref
         }) do
      [] -> {:ok, nil}
      _ -> {:ok, cache_implementations([implementation_ref], force: true)}
    end
  end

  def do_migration_implementation_id_to_implementation_ref do
    relations =
      "implementation"
      |> ImplementationCache.referenced_ids()
      |> Implementations.get_implementations_ref()

    relations
    |> Enum.map(fn [imp_id, imp_ref] ->
      ImplementationCache.delete(imp_id)
      imp_ref
    end)
    |> cache_implementations()

    relations
    |> List.flatten()
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

  def handle_cast({:implementation_ids_to_migrate_implementation_ref, _opts}, state) do
    ImplementationCache.delete_relation_impl_id_and_impl_ref()
    do_migration_implementation_id_to_implementation_ref()
    {:noreply, state}
  end

  @impl GenServer
  def handle_call({:consume, events}, _from, state) do
    Enum.each(events, &reindex_implementations/1)

    implementation_refs = Enum.flat_map(events, &read_implementation_refs/1)
    reply = cache_implementations(implementation_refs)
    {:reply, reply, state}
  end

  ## Private functions
  defp reindex_implementations(%{event: event, source: source, target: target})
       when event in ["add_link", "remove_link"] do
    ids =
      [source, target]
      |> extract_implementation_refs()
      |> Enum.map(&Implementations.get_implementation_versions_ids_by_ref(&1))
      |> List.flatten()

    Indexer.reindex(ids)
  end

  defp reindex_implementations(_), do: nil

  defp read_implementation_refs(%{event: event, source: source, target: target})
       when event in ["add_link", "remove_link"] do
    extract_implementation_refs([source, target])
  end

  # unsupported events...
  defp read_implementation_refs(_), do: []

  defp extract_implementation_refs(implementation_keys) do
    implementation_keys
    |> Enum.filter(&String.starts_with?(&1, "implementation_ref:"))
    |> Enum.uniq()
    |> Enum.map(fn "implementation_ref:" <> id -> id end)
    |> Enum.map(&String.to_integer/1)
  end

  def cache_implementations(implementation_refs, opts \\ []) do
    implementation_refs
    |> Enum.map(&get_linked_implementation/1)
    |> Enum.map(&maybe_delete_or_cache_implementations(&1, opts))
  end

  defp maybe_update_implementations_cache(implementations) do
    implementation_ref_to_cache =
      implementations
      |> Enum.map(fn %Implementation{implementation_ref: implementation_ref} = implementation ->
        case Implementations.get_implementation_links(implementation) do
          [] -> nil
          _ -> implementation_ref
        end
      end)
      |> Enum.filter(fn implementation_ref -> implementation_ref != nil end)
      |> Enum.uniq()

    {:ok, cache_implementations(implementation_ref_to_cache, force: true)}
  end

  defp maybe_delete_or_cache_implementations(implementation_ref, _opts)
       when is_number(implementation_ref) do
    {:ok, implementation_links} =
      LinkCache.list("implementation_ref", implementation_ref, "business_concept")

    Enum.each(implementation_links, &LinkCache.delete(&1.id))
    ImplementationCache.delete(implementation_ref)
  end

  defp maybe_delete_or_cache_implementations(%Implementation{} = implementation, opts) do
    ImplementationCache.put(implementation, opts)
  end

  defp get_linked_implementation(implementation_ref) do
    case Implementations.get_linked_implementation!(implementation_ref, preload: [:rule]) do
      nil ->
        implementation_ref

      %{id: implementation_id} = implementation ->
        quality_event = QualityEvents.get_event_by_imp(implementation_id)

        result = RuleResults.get_latest_rule_result(implementation)

        execution_result_info =
          Implementation.get_execution_result_info(implementation, result, quality_event)

        Map.put(implementation, :execution_result_info, execution_result_info)
    end
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
    keep_ids = ImplementationCache.referenced_ids("implementation_ref")
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
