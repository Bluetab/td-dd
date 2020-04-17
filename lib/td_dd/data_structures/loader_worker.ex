defmodule TdDd.Loader.LoaderWorker do
  @moduledoc """
  GenServer to handle bulk loading data dictionary
  """

  use GenServer

  alias TdCache.TaxonomyCache
  alias TdDd.CSV.Reader
  alias TdDd.DataStructures.Ancestry
  alias TdDd.DataStructures.Graph
  alias TdDd.Loader
  alias TdDd.ProfilingLoader
  alias TdDd.Systems

  require Logger

  @index_worker Application.get_env(:td_dd, :index_worker)

  @structure_import_schema Application.get_env(:td_dd, :metadata)[:structure_import_schema]
  @structure_import_required Application.get_env(:td_dd, :metadata)[:structure_import_required]
  @structure_import_boolean Application.get_env(:td_dd, :metadata)[:structure_import_boolean]
  @field_import_schema Application.get_env(:td_dd, :metadata)[:field_import_schema]
  @field_import_required Application.get_env(:td_dd, :metadata)[:field_import_required]
  @relation_import_schema Application.get_env(:td_dd, :metadata)[:relation_import_schema]
  @relation_import_required Application.get_env(:td_dd, :metadata)[:relation_import_required]

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def load(structures_file, fields_file, relations_file, audit, opts \\ []) do
    system_id = opts[:system_id]
    domain = opts[:domain]

    case Keyword.has_key?(opts, :external_id) do
      true ->
        GenServer.call(
          __MODULE__,
          {:load, structures_file, fields_file, relations_file, system_id, domain, audit, opts}
        )

      _ ->
        GenServer.cast(
          __MODULE__,
          {:load, structures_file, fields_file, relations_file, system_id, domain, audit}
        )
    end
  end

  def load(profiles) do
    GenServer.cast(TdDd.Loader.LoaderWorker, {:profiles, profiles})
  end

  def ping(timeout \\ 5000) do
    GenServer.call(__MODULE__, :ping, timeout)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:profiles, profiles}, state) do
    Logger.info("Bulk loading profiles")

    Timer.time(
      fn -> ProfilingLoader.load(profiles) end,
      fn ms, res ->
        case res do
          {:ok, ids} ->
            count = Enum.count(ids)
            Logger.info("Bulk load process completed in #{ms}ms (#{count} upserts)")

          _ ->
            Logger.warn("Bulk load failed after #{ms}")
        end
      end
    )

    {:noreply, state}
  end

  @impl true
  def handle_cast(
        {:load, structures_file, fields_file, relations_file, system_id, domain, audit},
        state
      ) do
    {:ok, field_recs} = parse_data_fields(fields_file, system_id)
    {:ok, structure_recs} = parse_data_structures(structures_file, system_id, domain)
    {:ok, relation_recs} = parse_data_structure_relations(relations_file, system_id)

    do_load(structure_recs, field_recs, relation_recs, audit)
    {:noreply, state}
  end

  @impl true
  def handle_call(
        {:load, structures_file, fields_file, relations_file, system_id, domain, audit, opts},
        _from,
        state
      ) do
    {:ok, field_recs} = parse_data_fields(fields_file, system_id)
    {:ok, structure_recs} = parse_data_structures(structures_file, system_id, domain)
    {:ok, relation_recs} = parse_data_structure_relations(relations_file, system_id)

    reply = do_load(structure_recs, field_recs, relation_recs, audit, opts)
    {:reply, reply, state}
  end

  @impl true
  def handle_call(:ping, _from, state) do
    {:reply, :pong, state}
  end

  defp do_load(structures, fields, relations, audit, opts \\ []) do
    Logger.info("Bulk loading data structures")
    graph = Graph.new()

    try do
      Timer.time(
        fn -> Loader.load(graph, structures, fields, relations, audit, opts) end,
        fn ms, res ->
          case res do
            {:ok, data_structure_ids} ->
              count = Enum.count(data_structure_ids)
              Logger.info("Bulk load process completed in #{ms}ms (#{count} upserts)")
              post_process(data_structure_ids, opts)

            e ->
              Logger.warn("Bulk load failed after #{ms}ms (#{inspect(e)})")
              e
          end
        end
      )
    after
      Graph.delete(graph)
    end
  end

  defp parse_data_structures(nil, _, _), do: {:ok, []}

  defp parse_data_structures(path, system_id, domain) do
    domain_names = TaxonomyCache.get_domain_name_to_id_map()
    domain_external_ids = TaxonomyCache.get_domain_external_id_to_id_map()
    system_map = get_system_map(system_id)

    defaults =
      case system_id do
        nil -> %{}
        _ -> %{system_id: system_id}
      end

    records =
      path
      |> File.stream!()
      |> Reader.read_csv(
        domain_names: domain_names,
        domain_external_ids: domain_external_ids,
        domain: domain,
        system_map: system_map,
        defaults: defaults,
        schema: @structure_import_schema,
        required: @structure_import_required,
        booleans: @structure_import_boolean
      )

    File.rm("#{path}")
    records
  end

  defp parse_data_fields(nil, _), do: {:ok, []}

  defp parse_data_fields(path, system_id) do
    defaults =
      case system_id do
        nil -> %{external_id: nil}
        _ -> %{external_id: nil, system_id: system_id}
      end

    system_map = get_system_map(system_id)

    records =
      path
      |> File.stream!()
      |> Reader.read_csv(
        defaults: defaults,
        system_map: system_map,
        schema: @field_import_schema,
        required: @field_import_required,
        booleans: ["nullable"]
      )

    File.rm("#{path}")
    records
  end

  defp parse_data_structure_relations(nil, _), do: {:ok, []}

  defp parse_data_structure_relations(path, system_id) do
    system_map = get_system_map(system_id)

    defaults =
      case system_id do
        nil -> %{}
        _ -> %{system_id: system_id}
      end

    records =
      path
      |> File.stream!()
      |> Reader.read_csv(
        defaults: defaults,
        system_map: system_map,
        schema: @relation_import_schema,
        required: @relation_import_required
      )

    File.rm("#{path}")
    records
  end

  defp get_system_map(nil), do: Systems.get_system_name_to_id_map()
  defp get_system_map(_system_id), do: nil

  defp post_process([], _), do: :ok

  defp post_process(data_structure_ids, opts) do
    do_post_process(data_structure_ids, opts[:external_id])
  end

  defp do_post_process(data_structure_ids, nil) do
    # If any ids have been returned by the bulk load process, these
    # data structures should be reindexed.
    @index_worker.reindex(data_structure_ids)
  end

  defp do_post_process(data_structure_ids, external_id) do
    #  As the ancestry of the loaded structure may have changed, also reindex
    # that data structure and it's descendents.
    external_id
    |> Ancestry.get_descendent_ids()
    |> Enum.concat(data_structure_ids)
    |> Enum.uniq()
    |> do_post_process(nil)
  end
end
