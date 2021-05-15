defmodule TdDd.Search.StructureEnricher do
  @moduledoc """
  GenServer to for data dictionary bulk indexing.
  """

  use GenServer

  alias TdCache.LinkCache
  alias TdCache.TaxonomyCache
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureTypes
  alias TdDfLib.Format

  require Logger

  ## Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def refresh(opts \\ []) do
    case Process.whereis(__MODULE__) do
      nil -> {:error, :not_started}
      pid -> GenServer.call(pid, :refresh, Keyword.get(opts, :timeout, 10_000))
    end
  end

  @doc """
  Enriches chunked data structures to improve indexing performance, avoiding
  the N+1 problems caused by enriching in Document.encode/1.
  """
  def enrich(structure, type \\ nil, content_opt \\ nil) do
    GenServer.call(__MODULE__, {:enrich, structure, type, content_opt})
  end

  def count, do: GenServer.call(__MODULE__, :count)

  ## GenServer Callbacks

  @impl true
  def init(_init_arg) do
    state = initial_state()
    Logger.info("started")
    {:ok, state}
  end

  @impl true
  def handle_call(:refresh, _from, _state) do
    {:reply, :ok, initial_state()}
  end

  @impl true
  def handle_call(:count, _from, %{count: count} = state) do
    {:reply, count, state}
  end

  @impl true
  def handle_call(
        {:enrich, data_structure, type, content_opt},
        _from,
        %{domains: domains, types: types, links: links, count: count} = state
      ) do
    reply =
      data_structure
      |> enrich_domain(domains)
      |> enrich_link_count(links)
      |> search_content(content_opt, types, type)

    {:reply, reply, %{state | count: count + 1}}
  end

  defp initial_state do
    %{
      count: 0,
      types: type_map(),
      domains: TaxonomyCache.domain_map(),
      links: LinkCache.link_count_map("data_structure", "business_concept")
    }
  end

  defp type_map do
    DataStructureTypes.list_data_structure_types()
    |> Enum.map(&DataStructureTypes.enrich_template/1)
    |> Map.new(fn %{structure_type: type, template: template} -> {type, template} end)
  end

  defp enrich_domain(%DataStructure{domain_id: domain_id} = structure, %{} = domains)
       when is_integer(domain_id) do
    %{structure | domain: Map.get(domains, domain_id, %{})}
  end

  defp enrich_domain(%DataStructure{} = structure, _),
    do: %{structure | domain: %{}}

  defp search_content(%DataStructure{df_content: %{} = content} = structure, :searchable, %{} = types, type)
       when map_size(content) > 0 do
    case Map.get(types, type) do
      %{} = template ->
        %{structure | search_content: search_content(content, template)}

      _ ->
        %{structure | search_content: nil}
    end
  end

  defp search_content(%DataStructure{} = structure, _not_searchable, _, _type), do: structure

  defp search_content(content, template), do: Format.search_values(content, template)

  defp enrich_link_count(%{id: id} = structure, %{} = links) do
    %{structure | linked_concepts_count: Map.get(links, id, 0)}
  end
end
