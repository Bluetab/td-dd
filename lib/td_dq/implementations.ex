defmodule TdDq.Implementations do
  @moduledoc """
  The Rule Implementations context.
  """

  import Canada, only: [can?: 2]
  import Canada.Can, only: [can?: 3]
  import Ecto.Query

  alias Ecto.Changeset
  alias Ecto.Multi
  alias TdCache.LinkCache
  alias TdCache.TaxonomyCache
  alias TdCx.Sources
  alias TdDd.Cache.StructureEntry
  alias TdDd.DataStructures
  alias TdDd.Repo
  alias TdDq.Auth.Claims
  alias TdDq.Cache.ImplementationLoader
  alias TdDq.Cache.RuleLoader
  alias TdDq.Events.QualityEvents
  alias TdDq.Implementations.Implementation
  alias TdDq.Implementations.ImplementationStructure
  alias TdDq.Rules
  alias TdDq.Rules.Audit
  alias TdDq.Rules.Rule
  alias TdDq.Search.Helpers

  @index_worker Application.compile_env(:td_dd, :dq_index_worker)

  @typep multi_result ::
           {:ok, map} | {:error, Multi.name(), any(), %{required(Multi.name()) => any()}}

  @doc """
  Gets a single implementation.

  Raises `Ecto.NoResultsError` if the Rule does not exist.

  ## Examples

      iex> get_implementation!(123)
      %Implementation{}

      iex> get_implementation!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_implementation!(integer, Keyword.t()) :: Implementation.t()
  def get_implementation!(id, opts \\ []) do
    preloads = Keyword.get(opts, :preload, :rule)

    Implementation
    |> preload(^preloads)
    |> Repo.get!(id)
    |> enrich(Keyword.get(opts, :enrich, []))
  end

  def get_implementation(id) do
    Repo.get(Implementation, id)
  end

  def get_implementation_by_key!(implementation_key, deleted \\ nil)

  def get_implementation_by_key!(implementation_key, true) do
    Implementation
    |> join(:inner, [ri], r in assoc(ri, :rule))
    |> Repo.get_by!(implementation_key: implementation_key)
    |> Repo.preload(:rule)
  end

  def get_implementation_by_key!(implementation_key, _deleted) do
    Implementation
    |> where([ri], is_nil(ri.deleted_at))
    |> Repo.get_by!(implementation_key: implementation_key)
    |> Repo.preload(:rule)
  end

  def last?(%Implementation{id: id, implementation_key: implementation_key}) do
    get_last_implementation_by_key!(implementation_key).id == id
  end

  def get_last_implementation_by_key!(implementation_key) do
    Implementation
    |> where([ri], ri.implementation_key == ^implementation_key)
    |> order_by(desc: :version)
    |> limit(1)
    |> Repo.one!()
  end

  @spec create_implementation(Rule.t(), map, Claims.t(), boolean) :: multi_result
  def create_implementation(rule, params, claims, is_bulk \\ false)

  def create_implementation(
        %Rule{} = rule,
        %{} = params,
        %Claims{user_id: user_id} = claims,
        is_bulk
      ) do
    changeset =
      Implementation.changeset(
        rule,
        %Implementation{},
        params
      )

    Multi.new()
    |> Multi.run(:can, fn _, _ ->
      multi_can(can?(claims, create(changeset)) and can?(claims, edit_segments(changeset)))
    end)
    |> Multi.insert(:implementation, changeset)
    |> Multi.run(:data_structures, &create_implementation_structures/2)
    |> Multi.run(:audit, Audit, :implementation_created, [changeset, user_id])
    |> Repo.transaction()
    |> on_upsert(is_bulk)
  end

  def create_implementation(nil, params, claims, is_bulk) do
    create_ruleless_implementation(params, claims, is_bulk)
  end

  @spec create_ruleless_implementation(map, Claims.t(), boolean) :: multi_result
  def create_ruleless_implementation(params, claims, is_bulk \\ false)

  def create_ruleless_implementation(
        %{} = params,
        %Claims{user_id: user_id} = claims,
        is_bulk
      ) do
    changeset =
      Implementation.changeset(
        %Implementation{},
        params
      )

    Multi.new()
    |> Multi.run(:can, fn _, _ ->
      multi_can(
        Enum.all?(
          [
            :edit_segments,
            :create_ruleless_implementations,
            :create
          ],
          &can?(claims, &1, changeset)
        )
      )
    end)
    |> Multi.insert(:implementation, changeset)
    |> Multi.run(:data_structures, &create_implementation_structures/2)
    |> Multi.run(:audit, Audit, :implementation_created, [changeset, user_id])
    |> Repo.transaction()
    |> on_upsert(is_bulk)
  end

  defp multi_can(true), do: {:ok, nil}
  defp multi_can(false), do: {:error, false}

  def update_implementation(
        %Implementation{} = implementation,
        params,
        %Claims{user_id: user_id} = claims
      ) do
    changeset = Implementation.changeset(implementation, params)

    Multi.new()
    |> Multi.run(:can, fn _, _ ->
      multi_can(
        Enum.all?([
          can?(claims, update(changeset)),
          can?(claims, edit_segments(implementation)),
          can?(claims, edit_segments(changeset))
        ])
      )
    end)
    |> Multi.update(:implementation, fn _ -> do_update_implementation(changeset) end)
    |> Multi.run(:data_structures, &create_implementation_structures/2)
    |> Multi.run(:audit, Audit, :implementation_updated, [changeset, user_id])
    |> Multi.run(:cache, ImplementationLoader, :maybe_update_implementation_cache, [])
    |> Repo.transaction()
    |> on_upsert()
  end

  defp do_update_implementation(%{changes: %{rule_id: rule_id}} = changeset) do
    case Rules.get_rule(rule_id) do
      %{domain_id: domain_id} -> Changeset.put_change(changeset, :domain_id, domain_id)
      _ -> changeset
    end
  end

  defp do_update_implementation(changeset), do: changeset

  @spec deprecate_implementations ::
          :ok | {:ok, map} | {:error, Multi.name(), any, %{required(Multi.name()) => any}}
  def deprecate_implementations do
    implementation_ids_by_structure_id =
      list_implementations()
      |> Enum.map(fn %{id: id} = impl -> {get_structure_ids(impl), id} end)
      |> Enum.flat_map(fn {structure_ids, id} -> Enum.map(structure_ids, &{&1, id}) end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    existing_structure_ids =
      implementation_ids_by_structure_id
      |> Map.keys()
      |> DataStructures.get_latest_versions()
      |> Enum.filter(&is_nil(&1.deleted_at))
      |> Enum.map(& &1.data_structure_id)

    implementation_ids_by_structure_id
    |> Map.drop(existing_structure_ids)
    |> Enum.flat_map(fn {_, impl_ids} -> impl_ids end)
    |> Enum.uniq()
    |> deprecate()
  end

  @spec deprecate(list(integer())) ::
          :ok | {:ok, map} | {:error, Multi.name(), any, %{required(Multi.name()) => any}}
  def deprecate([]), do: :ok

  def deprecate(ids) do
    ts = DateTime.utc_now()

    query =
      Implementation
      |> where([i], i.id in ^ids)
      |> where([i], is_nil(i.deleted_at))
      |> select([i], i)

    Multi.new()
    |> Multi.update_all(:deprecated, query, set: [deleted_at: ts, status: "deprecated"])
    |> Multi.run(:audit, Audit, :implementations_deprecated, [])
    |> Repo.transaction()
    |> on_deprecate()
  end

  defp on_deprecate(result) do
    case result do
      {:ok, %{deprecated: {_, [_ | _] = impls}}} ->
        impls
        |> Enum.map(& &1.id)
        |> @index_worker.reindex_implementations()

        result

      _ ->
        result
    end
  end

  def delete_implementation(
        %Implementation{} = implementation,
        %Claims{user_id: user_id} = claims
      ) do
    changeset =
      implementation
      |> Repo.preload(:rule)
      |> Changeset.change()

    Multi.new()
    |> Multi.run(:can, fn _, _ -> multi_can(can?(claims, delete(implementation))) end)
    |> Multi.delete(:implementation, changeset)
    |> Multi.run(:audit, Audit, :implementation_deleted, [changeset, user_id])
    |> Repo.transaction()
    |> on_delete()
  end

  defp on_delete({:ok, %{implementation: %{id: id, rule_id: rule_id}}} = result) do
    RuleLoader.refresh(rule_id)
    @index_worker.delete_implementations(id)
    result
  end

  defp on_delete(result), do: result

  @spec on_upsert(multi_result, boolean) :: multi_result
  defp on_upsert(result, is_bulk \\ false)

  defp on_upsert({:ok, %{implementation: %{id: id}}} = result, false) do
    @index_worker.reindex_implementations(id)
    result
  end

  defp on_upsert(result, _), do: result

  def get_sources(%Implementation{implementation_type: "raw", raw_content: %{source_id: nil}}) do
    []
  end

  def get_sources(%Implementation{
        implementation_type: "raw",
        raw_content: %{source_id: source_id}
      }) do
    Sources.get_aliases(source_id)
  end

  def get_sources(%Implementation{} = implementation) do
    implementation
    |> get_structure_ids()
    |> TdDq.Search.Helpers.get_sources()
  end

  def get_structures(%Implementation{} = implementation) do
    implementation
    |> Map.take([:dataset, :populations, :validations, :segments])
    |> Map.values()
    |> Enum.flat_map(&structure/1)
  end

  def get_structure_ids(%Implementation{} = implementation) do
    implementation
    |> get_structures()
    |> Enum.map(&Map.get(&1, :id))
    |> Enum.uniq()
  end

  @doc """
  Returns the next available implementation key

    ## Examples

      iex> next_key()
      "ri0001"

  """
  def next_key do
    next_ri =
      Implementation
      |> where([ri], fragment("? ~ ?", ri.implementation_key, "^ri\\d+$"))
      |> order_by([ri], fragment("right(?, -2)::INTEGER DESC", ri.implementation_key))
      |> select([ri], fragment("1 + right(?, -2)::INTEGER", ri.implementation_key))
      |> limit(1)
      |> Repo.all()
      |> Enum.max(fn -> 1 end)
      |> to_string()
      |> String.pad_leading(4, "0")

    "ri#{next_ri}"
  end

  @doc """
  Returns the list of implementations.

  ## Examples

      iex> list_implementations(params, opts)
      [%Implementation{}, ...]

  """
  def list_implementations(params \\ %{}, opts \\ [])

  def list_implementations(params, opts) do
    preloads = Keyword.get(opts, :preload, [])
    rule_params = Map.get(params, :rule) || Map.get(params, "rule", %{})
    rule_fields = Rule.__schema__(:fields)
    implementation_fields = Implementation.__schema__(:fields)

    dynamic = dynamic_params(:implementation, params, implementation_fields, true)
    dynamic = dynamic_params(:rule, rule_params, rule_fields, dynamic)

    Implementation
    |> join(:inner, [ri], r in assoc(ri, :rule))
    |> where(^dynamic)
    |> where([_ri, r], is_nil(r.deleted_at))
    |> deleted_implementations(opts, :implementations)
    |> preload(^preloads)
    |> Repo.all()
    |> enrich(Keyword.get(opts, :enrich))
  end

  def get_rule_implementations([]), do: []

  def get_rule_implementations(rule_ids) do
    Implementation
    |> where([ri], ri.rule_id in ^rule_ids)
    |> Repo.all()
  end

  defp dynamic_params(entity, params, fields, dynamic) do
    params
    |> Map.new(fn
      {k, v} when is_binary(k) -> {String.to_atom(k), v}
      kv -> kv
    end)
    |> Map.take(fields)
    |> Enum.reduce(dynamic, fn {field, value}, acc ->
      dynamic_filter(value, field, acc, entity)
    end)
  end

  defp dynamic_filter({:in, values}, atom_name, acc, :implementation) when is_list(values) do
    dynamic([p, _], field(p, ^atom_name) in ^values and ^acc)
  end

  defp dynamic_filter(field, atom_name, acc, :implementation) when is_map(field) do
    dynamic([p, _], fragment("(?) @> ?::jsonb", field(p, ^atom_name), ^field) and ^acc)
  end

  defp dynamic_filter(field, atom_name, acc, :implementation) do
    dynamic([p, _], field(p, ^atom_name) == ^field and ^acc)
  end

  defp dynamic_filter(field, atom_name, acc, :rule) when is_map(field) do
    dynamic([_, p], fragment("(?) @> ?::jsonb", field(p, ^atom_name), ^field) and ^acc)
  end

  defp dynamic_filter(field, atom_name, acc, :rule) do
    dynamic([_, p], field(p, ^atom_name) == ^field and ^acc)
  end

  defp deleted_implementations(query, options, order) do
    if Keyword.get(options, :deleted, false) do
      with_deleted(query, order)
    else
      without_deleted(query, order)
    end
  end

  defp with_deleted(query, :implementations) do
    where(query, [ri, _r], not is_nil(ri.deleted_at))
  end

  defp without_deleted(query, :implementations) do
    where(query, [ri, _r], is_nil(ri.deleted_at))
  end

  def valid_dataset_implementation_structures(%Implementation{dataset: [_ | _] = dataset}) do
    dataset
    |> Enum.map(fn dataset_row -> dataset_row |> Map.get(:structure) |> Map.get(:id) end)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&DataStructures.get_data_structure/1)
    |> Enum.reject(&is_nil/1)
  end

  def valid_dataset_implementation_structures(%Implementation{
        raw_content: %{
          database: database,
          dataset: dataset,
          source_id: source_id
        }
      }) do
    names = string_split_space_lower(dataset)

    [
      {:not_deleted, nil},
      {:name_in, names},
      {:source_id, source_id},
      {:metadata_field, {"database", database}},
      {:class, "table"}
    ]
    |> DataStructures.list_data_structure_versions_by_criteria()
    |> Enum.map(fn dsv ->
      dsv
      |> Repo.preload(:data_structure)
      |> Map.get(:data_structure)
    end)
  end

  def valid_dataset_implementation_structures(_), do: []

  def valid_validation_implementation_structures(%Implementation{
        validations: [_ | _] = validations
      }) do
    validations
    |> Enum.map(fn dataset_row -> dataset_row |> Map.get(:structure) |> Map.get(:id) end)
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&DataStructures.get_data_structure/1)
    |> Enum.reject(&is_nil/1)
  end

  def valid_validation_implementation_structures(%Implementation{
        raw_content: %{
          database: database,
          dataset: dataset,
          validations: validations,
          source_id: source_id
        }
      }) do
    names = string_split_space_lower(validations)
    dataset_names = string_split_space_lower(dataset)

    [
      {:not_deleted, nil},
      {:name_in, names},
      {:source_id, source_id},
      {:metadata_field, {"database", database}},
      {:metadata_field_in, {"table", dataset_names}}
    ]
    |> DataStructures.list_data_structure_versions_by_criteria()
    |> Enum.map(fn dsv ->
      dsv
      |> Repo.preload(:data_structure)
      |> Map.get(:data_structure)
    end)
  end

  def valid_validation_implementation_structures(_), do: []

  defp string_split_space_lower(str),
    do: str |> String.split(~r/[\s\.\*\&\|\^\%\/()><!=,+-]+/) |> Enum.map(&String.downcase/1)

  defp create_implementation_structures(_repo, %{implementation: implementation}) do
    results_dataset =
      implementation
      |> valid_dataset_implementation_structures()
      |> Enum.map(
        &create_implementation_structure(implementation, &1, %{type: :dataset},
          on_conflict: :nothing
        )
      )

    results_validations =
      implementation
      |> valid_validation_implementation_structures()
      |> Enum.map(
        &create_implementation_structure(implementation, &1, %{type: :validation},
          on_conflict: :nothing
        )
      )

    case Enum.group_by(results_dataset ++ results_validations, &elem(&1, 0), &elem(&1, 1)) do
      %{error: errors} -> {:error, errors}
      %{ok: oks} -> {:ok, oks}
      %{} -> {:ok, []}
    end
  end

  def enrich_implementation_structures(%Implementation{} = implementation) do
    enriched_dataset =
      Enum.map(implementation.dataset, fn dataset_row ->
        case dataset_row |> Map.get(:structure) |> Map.get(:id) do
          nil ->
            dataset_row

          id ->
            cached_structure = StructureEntry.cache_entry(id, system: true)

            dataset_row
            |> Map.put(
              :structure,
              put_structure_cached_attributes(Map.get(dataset_row, :structure), cached_structure)
            )
            |> enrich_joined_structures
        end
      end)

    enriched_populations = Enum.map(implementation.populations, &enrich_populations/1)
    enriched_validations = Enum.map(implementation.validations, &enrich_condition/1)
    enriched_segments = Enum.map(implementation.segments, &enrich_condition/1)

    enriched_data_structures = enrich_data_structures_path(implementation)

    implementation
    |> Map.put(:dataset, enriched_dataset)
    |> Map.put(:populations, enriched_populations)
    |> Map.put(:validations, enriched_validations)
    |> Map.put(:segments, enriched_segments)
    |> Map.put(:data_structures, enriched_data_structures)
  end

  defp enrich_data_structures_path(%{data_structures: [_ | _] = data_structures}) do
    data_structure_ids =
      data_structures
      |> Enum.map(fn
        %{data_structure: %{current_version: %{id: id}}} -> id
        _ -> nil
      end)
      |> Enum.reject(&is_nil/1)

    paths_map =
      [ids: data_structure_ids]
      |> DataStructures.enriched_structure_versions()
      |> Enum.map(fn %{data_structure_id: id, path: path} ->
        {id, Enum.map(path, fn %{"name" => name} -> name end)}
      end)
      |> Map.new()

    Enum.map(data_structures, fn
      %{
        data_structure: %{current_version: %{} = current_version} = data_structure
      } = implementation_structure ->
        %{
          implementation_structure
          | data_structure: %{
              data_structure
              | current_version: %{current_version | path: Map.get(paths_map, data_structure.id)}
            }
        }

      implementation_structure ->
        implementation_structure
    end)
  end

  defp enrich_data_structures_path(_), do: []

  defp enrich_populations(%{population: population} = populations) do
    %{populations | population: Enum.map(population, &enrich_condition/1)}
  end

  defp enrich_populations(populations), do: populations

  defp enrich_condition(%{structure: structure = %{}} = condition) do
    cached_structure = StructureEntry.cache_entry(Map.get(structure, :id), system: true)

    enriched_info =
      condition
      |> Map.get(:structure)
      |> put_structure_cached_attributes(cached_structure)

    condition
    |> Map.put(:structure, enriched_info)
    |> enrich_value_structures()
    |> with_population()
  end

  defp enrich_condition(condition), do: condition

  defp enrich_joined_structures(%{clauses: clauses} = structure_map) when is_list(clauses) do
    clauses = Enum.map(clauses, &enrich_clause_structures/1)
    Map.put(structure_map, :clauses, clauses)
  end

  defp enrich_joined_structures(structure_map) do
    structure_map
  end

  defp enrich_clause_structures(
         %{left: %{id: left_id} = left, right: %{id: right_id} = right} = structure_map
       ) do
    structure_map
    |> Map.put(
      :left,
      put_structure_cached_attributes(
        %{id: left_id, parent_index: Map.get(left, :parent_index)},
        StructureEntry.cache_entry(left_id, system: true)
      )
    )
    |> Map.put(
      :right,
      put_structure_cached_attributes(
        %{id: right_id, parent_index: Map.get(right, :parent_index)},
        StructureEntry.cache_entry(right_id, system: true)
      )
    )
  end

  defp enrich_value_structure(%{"id" => id} = value_map) do
    cached_structure = StructureEntry.cache_entry(id, system: true)
    put_structure_cached_attributes(value_map, cached_structure)
  end

  defp enrich_value_structure(value_map) do
    value_map
  end

  defp enrich_value_structures(row) do
    values = Map.get(row, :value)

    case values do
      nil ->
        row

      _ ->
        values = Enum.map(values, &enrich_value_structure/1)

        Map.put(row, :value, values)
    end
  end

  defp with_population(%{population: population} = condition) when is_list(population) do
    %{condition | population: Enum.map(population, &enrich_condition/1)}
  end

  defp with_population(condition), do: condition

  defp put_structure_cached_attributes(structure_map, cached_info) do
    structure_map =
      structure_map
      |> Map.Helpers.atomize_keys()
      |> Map.put(:external_id, Map.get(cached_info, :external_id))
      |> Map.put(:name, Map.get(cached_info, :name, Map.get(structure_map, :name, "")))
      |> Map.put(:path, Map.get(cached_info, :path, []))
      |> Map.put(:system, Map.get(cached_info, :system))
      |> Map.put(:type, Map.get(cached_info, :type))

    case Map.get(cached_info, :metadata) do
      nil -> structure_map
      metadata -> Map.put(structure_map, :metadata, metadata)
    end
  end

  defp structure([_ | _] = values), do: Enum.flat_map(values, &structure/1)

  defp structure(%{structure: structure, value: nil}),
    do: structure(structure)

  defp structure(%{structure: structure, value: values}),
    do: structure([structure | values])

  defp structure(%{structure: structure, clauses: nil}),
    do: structure(structure)

  defp structure(%{structure: structure, clauses: clauses}),
    do: structure([structure | clauses])

  defp structure(%{structure: structure}),
    do: structure(structure)

  defp structure(%{left: left = %{}, right: right = %{}}),
    do: [Map.take(left, [:id, :name]), Map.take(right, [:id, :name])]

  defp structure(%{value: value}), do: structure(value)

  defp structure(%{id: _id} = structure),
    do: [Map.take(structure, [:id, :name])]

  defp structure(%{"id" => id} = structure) do
    name = Map.get(structure, "name")
    [%{id: id, name: name}]
  end

  defp structure(%{population: population}) do
    structure(population)
  end

  defp structure(_any), do: []

  def enrich_implementations(target, opts), do: enrich(target, opts)

  @spec enrich(Implementation.t() | [Implementation.t()], nil | atom | [atom]) ::
          Implementation.t() | [Implementation.t()]
  defp enrich(target, nil), do: target

  defp enrich(target, opts) when is_list(target) do
    Enum.map(target, &enrich(&1, opts))
  end

  defp enrich(target, opts) when is_list(opts) do
    Enum.reduce(opts, target, &enrich(&2, &1))
  end

  defp enrich(
         %Implementation{
           implementation_type: "raw",
           raw_content: %{source_id: source_id} = content
         } = implementation,
         :source
       )
       when is_integer(source_id) do
    case Sources.get_source(source_id) do
      nil ->
        implementation

      source ->
        content = %{content | source: source}
        %{implementation | raw_content: content}
    end
  end

  defp enrich(%Implementation{} = implementation, :links) do
    Map.put(implementation, :links, get_implementation_links(implementation, "business_concept"))
  end

  defp enrich(%Implementation{} = implementation, :execution_result_info) do
    quality_event = QualityEvents.get_event_by_imp(implementation.id)

    execution_result_info =
      Implementation.get_execution_result_info(implementation, quality_event)

    Map.put(implementation, :execution_result_info, execution_result_info)
  end

  defp enrich(
         %Implementation{rule: %Rule{} = rule} = implementation,
         :current_business_concept_version
       ) do
    bcv = Helpers.get_business_concept_version(rule)
    Map.put(implementation, :current_business_concept_version, bcv)
  end

  defp enrich(%Implementation{domain_id: domain_id} = implementation, :domain)
       when is_integer(domain_id) do
    case TaxonomyCache.get_domain(domain_id) do
      %{id: ^domain_id} = domain ->
        %{implementation | domain: Map.take(domain, [:id, :name, :external_id])}

      _ ->
        implementation
    end
  end

  defp enrich(target, _), do: target

  def get_implementation_links(%Implementation{id: id}) do
    case LinkCache.list("implementation", id) do
      {:ok, links} -> links
    end
  end

  def get_implementation_links(%Implementation{id: id}, target_type) do
    case LinkCache.list("implementation", id, target_type) do
      {:ok, links} -> links
    end
  end

  def get_implementation_structure!(implementation_structure_id, preloads \\ []) do
    ImplementationStructure
    |> where([is], is_nil(is.deleted_at))
    |> Repo.get!(implementation_structure_id)
    |> Repo.preload(preloads)
  end

  def create_implementation_structure(
        implementation,
        data_structure,
        attrs \\ %{},
        opts \\ [
          on_conflict: [set: [deleted_at: nil]],
          conflict_target: [:implementation_id, :data_structure_id, :type]
        ]
      ) do
    %ImplementationStructure{}
    |> ImplementationStructure.changeset(
      attrs,
      implementation,
      data_structure
    )
    |> Repo.insert(opts)
  end

  def delete_implementation_structure(%ImplementationStructure{} = implementation_structure) do
    implementation_structure
    |> ImplementationStructure.delete_changeset()
    |> Repo.update()
  end
end
