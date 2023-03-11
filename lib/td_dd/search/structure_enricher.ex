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
    GenServer.call(__MODULE__, {:enrich, structure, type, content_opt}, 65_000)
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
        %{
          types: types,
          links: links,
          count: count
        } = state
      ) do
    reply =
      data_structure
      |> enrich_domains
      |> enrich_links(links)
      |> search_content(content_opt, types, type)

    {:reply, reply, %{state | count: count + 1}}
  end

  defp initial_state do
    %{
      count: 0,
      types: type_map(),
      links: LinkCache.linked_source_ids("data_structure", "business_concept")
    }
  end

  defp type_map do
    DataStructureTypes.list_data_structure_types()
    |> Map.new(fn %{name: type, template: template} -> {type, template} end)
  end

  defp enrich_domains(%DataStructure{domain_ids: [_ | _] = domain_ids} = structure) do
    domains =
      Enum.map(domain_ids, fn domain_id ->
        case TaxonomyCache.get_domain(domain_id) do
          %{} = domain -> Map.put(domain, :parents, get_domain_parents(domain.id))
          nil -> %{}
        end
      end)

    %{structure | domains: domains}
  end

  defp enrich_domains(%DataStructure{} = structure),
    do: %{structure | domains: [%{}]}

  def get_domain_parents(id) do
    id
    |> get_domain_parent_ids()
    |> Enum.drop(1)
    |> Enum.map(&TaxonomyCache.get_domain/1)
    |> Enum.filter(& &1)
    |> Enum.map(&Map.take(&1, [:id, :external_id, :name]))
    |> Enum.reverse()
  end

  def get_domain_parent_ids(nil), do: []
  def get_domain_parent_ids(id), do: TaxonomyCache.reaching_domain_ids(id)

  defp search_content(
         %DataStructure{domain_ids: domain_ids, published_note: %{df_content: %{} = content}} =
           structure,
         :searchable,
         %{} = types,
         type
       )
       when map_size(content) > 0 do
    case Map.get(types, type) do
      %{} = template ->
        %{structure | search_content: search_content(content, template, domain_ids)}

      _ ->
        %{structure | search_content: nil}
    end
  end

  defp search_content(%DataStructure{} = structure, _not_searchable, _, _type), do: structure

  defp search_content(content, template, domain_ids) do
    Format.search_values(content, template, domain_ids: domain_ids)
  end

  defp enrich_links(%{id: id} = structure, links) do
    %{structure | linked_concepts: Enum.member?(links, id)}
  end
end
