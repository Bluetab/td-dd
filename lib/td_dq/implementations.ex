defmodule TdDq.Implementations do
  @moduledoc """
  The Rule Implementations context.
  """

  import Ecto.Query

  alias Ecto.Changeset
  alias Ecto.Multi
  alias TdCache.LinkCache
  alias TdCache.TaxonomyCache
  alias TdCache.TemplateCache
  alias TdCore.Search.IndexWorker
  alias TdCx.Sources
  alias TdDd.Cache.StructureEntry
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.ReferenceData
  alias TdDd.Repo
  alias TdDd.Search.StructureEnricher
  alias TdDfLib.Format
  alias TdDq.Cache.ImplementationLoader
  alias TdDq.Cache.RuleLoader
  alias TdDq.Events.QualityEvents
  alias TdDq.Implementations.Implementation
  alias TdDq.Implementations.ImplementationStructure
  alias TdDq.Implementations.Workflow
  alias TdDq.Rules
  alias TdDq.Rules.Audit
  alias TdDq.Rules.Rule
  alias TdDq.Rules.RuleResults
  alias TdDq.Search.Helpers
  alias Truedat.Auth.Claims

  @typep multi_result ::
           {:ok, map} | {:error, Multi.name(), any(), %{required(Multi.name()) => any()}}

  defdelegate authorize(action, user, params), to: __MODULE__.Policy

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

  ## used only for migrations
  def get_implementations_ref(ids) do
    Implementation
    |> where([i], i.id in ^ids)
    |> select([i], [i.id, i.implementation_ref])
    |> Repo.all()
  end

  def get_versions(%{implementation_ref: implementation_ref}) do
    Implementation
    |> where([i], i.implementation_ref == ^implementation_ref)
    |> order_by(desc: :version)
    |> Repo.all()
  end

  def get_published_implementation_by_key(implementation_key) do
    Implementation
    |> where([ri], ri.status == :published)
    |> Repo.get_by(implementation_key: implementation_key)
    |> Repo.preload(:rule)
    |> case do
      nil -> {:error, :not_found}
      implementation -> {:ok, implementation}
    end
  end

  def get_linked_implementation!(implementation_ref, opts \\ []) do
    status_order = Workflow.get_workflow_status_order()
    preloads = Keyword.get(opts, :preload, :rule)

    Implementation
    |> preload(^preloads)
    |> where([ri], ri.implementation_ref == ^implementation_ref)
    |> order_by(fragment("position(status::text in ?)", ^status_order))
    |> order_by(desc: :version)
    |> limit(1)
    |> Repo.one()
  end

  def last?(%Implementation{id: id, implementation_ref: implementation_ref}) do
    Implementation
    |> where([ri], ri.implementation_ref == ^implementation_ref)
    |> order_by(desc: :version)
    |> select([ri], ri.id == ^id)
    |> limit(1)
    |> Repo.one()
    |> Kernel.!=(false)
  end

  def last_by_keys([%{"implementation_key" => _} | _] = implementations_params) do
    implementations_params
    |> Enum.map(&Map.get(&1, "implementation_key"))
    |> last_by_keys()
  end

  def last_by_keys(implementation_keys) when is_list(implementation_keys) do
    Implementation
    |> where([i], i.implementation_key in ^implementation_keys)
    |> distinct([i], i.implementation_key)
    |> order_by([i], desc: i.version)
    |> TdDd.Repo.all()
  end

  @spec create_implementation(Rule.t(), map, Claims.t(), boolean) ::
          multi_result | {:error, :forbidden}
  def create_implementation(rule, params, claims, is_bulk \\ false)

  def create_implementation(
        %Rule{id: rule_id, domain_id: domain_id} = rule,
        %{} = params,
        %Claims{user_id: user_id} = claims,
        is_bulk
      ) do
    changeset =
      Implementation.changeset(
        %Implementation{
          version: 1,
          status: :draft,
          rule_id: rule_id,
          domain_id: domain_id,
          rule: rule
        },
        params
      )

    if Bodyguard.permit?(__MODULE__, :create, claims, changeset) and
         permit_by_changeset_status?(claims, changeset) do
      Multi.new()
      |> Multi.run(:implementation, fn _, _ -> insert_implementation(changeset) end)
      |> Multi.run(:data_structures, &create_implementation_structures/2)
      |> Multi.run(:audit, Audit, :implementation_created, [changeset, user_id])
      |> Repo.transaction()
      |> on_upsert(is_bulk)
    else
      {:error, {Changeset.fetch_field!(changeset, :implementation_key), :forbidden}}
    end
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
        %Implementation{version: 1, status: :draft},
        params
      )

    if Bodyguard.permit?(__MODULE__, :create, claims, changeset) and
         permit_by_changeset_status?(claims, changeset) do
      Multi.new()
      |> Multi.run(:implementation, fn _, _ -> insert_implementation(changeset) end)
      |> Multi.run(:data_structures, &create_implementation_structures/2)
      |> Multi.run(:audit, Audit, :implementation_created, [changeset, user_id])
      |> Repo.transaction()
      |> on_upsert(is_bulk)
    else
      {:error, {Changeset.fetch_field!(changeset, :implementation_key), :forbidden}}
    end
  end

  def permit_by_changeset_status(
        claims,
        %Ecto.Changeset{changes: %{status: _status_change}} = changeset
      ) do
    Bodyguard.permit(__MODULE__, :publish, claims, changeset)
  end

  def permit_by_changeset_status(_claims, %Ecto.Changeset{}), do: :ok

  def permit_by_changeset_status?(
        claims,
        %Ecto.Changeset{changes: %{status: _status_change}} = changeset
      ) do
    Bodyguard.permit?(__MODULE__, :publish, claims, changeset)
  end

  def permit_by_changeset_status?(_claims, %Ecto.Changeset{}), do: true

  def maybe_update_implementation(%Implementation{} = implementation, params, %Claims{} = claims) do
    if need_update?(implementation, params) do
      update_implementation(implementation, params, claims)
    else
      {:ok, %{implementation: implementation, error: :implementation_unchanged}}
    end
  end

  def update_implementation(implementation, params, claims, is_bulk \\ false)

  def update_implementation(
        %Implementation{rule_id: rule_id} = implementation,
        %{"rule_id" => new_rule_id} = params,
        %Claims{user_id: user_id} = claims,
        is_bulk
      )
      when rule_id != new_rule_id do
    changeset = upsert_changeset(implementation, params)

    with :ok <- Bodyguard.permit(__MODULE__, :move, claims, changeset),
         :ok <- permit_by_changeset_status(claims, changeset) do
      Multi.new()
      |> upsert(changeset)
      |> Multi.run(:implementation, fn _repo, _changes -> {:ok, implementation} end)
      |> Multi.run(:cache, ImplementationLoader, :maybe_update_implementation_cache, [])
      |> Multi.run(:audit, Audit, :implementation_updated, [changeset, user_id])
      |> Repo.transaction()
      |> on_upsert(is_bulk)
    end
  end

  def update_implementation(
        %Implementation{status: status, implementation_key: implementation_key},
        _,
        _,
        _
      )
      when status in [:deprecated, :pending_approval, :versioned] do
    {:error, {implementation_key, status}}
  end

  def update_implementation(
        %Implementation{status: status} = implementation,
        params,
        %Claims{user_id: user_id} = claims,
        is_bulk
      ) do
    changeset = upsert_changeset(implementation, params)

    with :ok <- Bodyguard.permit(__MODULE__, :update, claims, changeset),
         :ok <- permit_by_changeset_status(claims, changeset) do
      Multi.new()
      |> Workflow.maybe_version_existing(changeset, user_id)
      |> upsert(changeset, status)
      |> Multi.run(:data_structures, &create_implementation_structures/2)
      |> Multi.run(:audit_status, Audit, :implementation_status_updated, [changeset, user_id])
      |> Multi.run(:cache, ImplementationLoader, :maybe_update_implementation_cache, [])
      |> Multi.run(:audit, Audit, :implementation_updated, [changeset, user_id])
      |> Repo.transaction()
      |> on_upsert(is_bulk)
    else
      {:error, :forbidden} ->
        {:error, {Changeset.fetch_field!(changeset, :implementation_key), :forbidden}}

      error ->
        error
    end
  end

  defp need_update?(implementation, %{"status" => "draft"} = params) do
    need_update?(implementation, Map.drop(params, ["status"]))
  end

  defp need_update?(implementation, params) do
    implementation
    |> Implementation.changeset(params)
    |> Map.get(:changes)
    |> Map.drop([:updated_at]) != %{}
  end

  defp upsert(multi, changeset, :published), do: Multi.insert(multi, :implementation, changeset)
  defp upsert(multi, changeset, :draft), do: Multi.update(multi, :implementation, changeset)
  defp upsert(multi, changeset, :rejected), do: Multi.update(multi, :implementation, changeset)

  defp upsert(multi, %{data: implementation, changes: %{rule_id: rule_id}}) do
    %{domain_id: new_domain_id} = Repo.get!(Rule, rule_id)

    query =
      Implementation
      |> where([i], i.implementation_ref == ^implementation.implementation_ref)
      |> select([i], i)

    multi
    |> Multi.update_all(
      :implementations_moved,
      query,
      set: [rule_id: rule_id, domain_id: new_domain_id]
    )
  end

  defp upsert_changeset(
         %Implementation{
           status: :published,
           version: v
         } = implementation,
         %{} = params
       ) do
    Implementation.changeset(
      %{implementation | status: nil, id: nil, version: v + 1},
      params
    )
  end

  defp upsert_changeset(%Implementation{} = implementation, %{} = params) do
    implementation
    |> Implementation.changeset(params)
    |> maybe_put_domain_id()
  end

  defp maybe_put_domain_id(%{changes: %{rule_id: rule_id}} = changeset) do
    case Rules.get_rule(rule_id) do
      %{domain_id: domain_id} -> Changeset.put_change(changeset, :domain_id, domain_id)
      _ -> changeset
    end
  end

  defp maybe_put_domain_id(changeset), do: changeset

  @spec deprecate_implementations ::
          :ok | {:ok, map} | {:error, Multi.name(), any, %{required(Multi.name()) => any}}
  def deprecate_implementations do
    {
      implementation_ids_by_structure_id,
      implementation_ids_by_reference_dataset_id
    } =
      list_implementations()
      |> Enum.map(fn %{id: id} = impl -> {get_structures(impl), id} end)
      |> Enum.flat_map(fn {structures, id} -> Enum.map(structures, &{&1, id}) end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.reduce({%{}, %{}}, fn
        {%{id: id, type: "reference_dataset"}, impls}, {by_structures, by_references} ->
          {by_structures, Map.put(by_references, id, impls)}

        {%{id: id, type: _}, impls}, {by_structures, by_references} ->
          {Map.put(by_structures, id, impls), by_references}
      end)

    existing_structure_ids =
      implementation_ids_by_structure_id
      |> Map.keys()
      |> DataStructures.get_latest_versions()
      |> Enum.filter(&is_nil(&1.deleted_at))
      |> Enum.map(& &1.data_structure_id)

    impl_ids_to_deprecate_by_structure_id =
      implementation_ids_by_structure_id
      |> Map.drop(existing_structure_ids)
      |> Enum.flat_map(fn {_, impl_ids} -> impl_ids end)

    impl_ids_to_deprecate_by_reference_id =
      implementation_ids_by_reference_dataset_id
      |> Enum.reject(fn {id, _impl_ids} -> ReferenceData.exists?(id) end)
      |> Enum.flat_map(fn {_, impl_ids} -> impl_ids end)

    impl_ids_to_deprecate =
      Enum.uniq(
        impl_ids_to_deprecate_by_structure_id ++
          impl_ids_to_deprecate_by_reference_id
      )

    deprecate(impl_ids_to_deprecate)
  end

  @doc """
  Deprecate a list of implementations by ids

  This function is used for automatic deprecation.
  When a data structure is deleted and is related to an Implementation

  ## Examples

      iex> deprecate([1,2,3])
      {:ok,
      %{
        audit: ["1656487740089-0"],
        audit_status: :unchanged,
        deprecated: {1,[%Implementation{}, ...]}
      }}

      iex> deprecate([])
      {:ok, %{audit: [], audit_status: :unchanged, deprecated: {0, []}}}

  """
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
        ids = Enum.map(impls, & &1.id)
        IndexWorker.reindex(:implementations, ids)

        result

      _ ->
        result
    end
  end

  def delete_implementation(
        %Implementation{status: :published} = implementation,
        %Claims{user_id: user_id}
      ) do
    changeset =
      implementation
      |> Repo.preload(:rule)
      |> Implementation.changeset(%{status: :deprecated, deleted_at: DateTime.utc_now()})

    Multi.new()
    |> Multi.update(:implementation, changeset)
    |> Multi.run(:cache, ImplementationLoader, :maybe_update_implementation_cache, [])
    |> Multi.run(:audit_status, Audit, :implementation_status_updated, [changeset, user_id])
    |> Repo.transaction()
    |> on_upsert()
  end

  def delete_implementation(
        %Implementation{} = implementation,
        %Claims{user_id: user_id}
      ) do
    implementation
    |> prepare_query_phisical_delete()
    |> phisical_delete(user_id)
  end

  defp prepare_query_phisical_delete(%Implementation{
         status: :deprecated,
         implementation_ref: implementation_ref_id
       }) do
    Implementation
    |> where([i], i.implementation_ref == ^implementation_ref_id)
    |> select([i], i)
  end

  defp prepare_query_phisical_delete(%Implementation{
         id: implementation_id
       }) do
    Implementation
    |> where([i], i.id == ^implementation_id and i.status != :versioned)
    |> select([i], i)
  end

  defp phisical_delete(query, user_id) do
    Multi.new()
    |> Multi.delete_all(:implementations, query)
    |> Multi.run(:cache, ImplementationLoader, :maybe_update_implementation_cache, [])
    |> Multi.run(:audit, Audit, :implementations_deleted, [user_id])
    |> Repo.transaction()
    |> on_delete()
  end

  defp on_delete({:ok, %{implementations: {_count, implementations}}} = result) do
    {rule_ids, implementation_ids} =
      Enum.reduce(
        implementations,
        {MapSet.new(), MapSet.new()},
        fn %{rule_id: rule_id, id: implementation_id}, {rule_ids_set, implementation_ids_set} ->
          {
            MapSet.put(rule_ids_set, rule_id),
            MapSet.put(implementation_ids_set, implementation_id)
          }
        end
      )
      |> then(fn {rule_ids_set, implementation_ids_set} ->
        {MapSet.to_list(rule_ids_set), MapSet.to_list(implementation_ids_set)}
      end)

    RuleLoader.refresh(rule_ids)
    IndexWorker.delete(:implementations, implementation_ids)

    result
  end

  defp on_delete(result), do: result

  @spec on_upsert(multi_result, boolean) :: multi_result
  defp on_upsert(result, is_bulk \\ false)

  defp on_upsert({:ok, %{versioned: {_count, ids}, implementation: %{id: id}}} = result, false) do
    IndexWorker.reindex(:implementations, [id | ids])
    result
  end

  defp on_upsert({:ok, %{implementation: %{id: id}}} = result, false) do
    IndexWorker.reindex(:implementations, [id])
    result
  end

  defp on_upsert({:ok, %{implementations_moved: {_, implementations}}} = result, false) do
    ids = Enum.map(implementations, fn %{id: id} -> id end)

    IndexWorker.reindex(:implementations, ids)

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
    |> then(&Map.put(&1, :validations, flatten_conditions_set(&1.validation)))
    |> then(&Map.put(&1, :populations, flatten_conditions_set(&1.populations)))
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
    |> join(:left, [ri], r in assoc(ri, :rule))
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
    |> Enum.reject(fn dataset_row ->
      dataset_row |> Map.get(:structure) |> Map.get(:type) == "reference_dataset"
    end)
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
    names = get_string_elements(dataset)

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

  def flatten_conditions_set([%{} | _] = conditions_set) do
    conditions_set
    |> Enum.reduce([], fn %{conditions: conditions}, acc ->
      acc ++ conditions
    end)
  end

  def flatten_conditions_set(data), do: data

  def valid_validation_implementation_structures(%Implementation{
        validation: [_ | _] = validation
      }) do
    validation
    |> flatten_conditions_set()
    |> Enum.reject(fn dataset_row ->
      dataset_row |> Map.get(:structure) |> Map.get(:type) == "reference_dataset_field"
    end)
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
    names = get_string_elements(validations)
    dataset_names = get_string_elements(dataset)

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

  defp get_string_elements(str) do
    ~r/(?:\"(.*?)\"|[^"\s.*&|^%\/()><!=,+\-]+)+/
    |> Regex.scan(str)
    |> Enum.map(&List.last(&1))
  end

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

  defp insert_implementation(changeset) do
    with {:ok, %{id: id} = implementation} <- Repo.insert(changeset) do
      implementation
      |> Implementation.implementation_ref_changeset(%{implementation_ref: id})
      |> Repo.update()
    end
  end

  def enrich_implementation_structures(
        %Implementation{} = implementation,
        preload_structure \\ true
      ) do
    enriched_dataset =
      implementation
      |> Map.get(:dataset)
      |> Enum.map(&enrich_dataset_row/1)

    enriched_populations = Enum.map(implementation.populations, &enrich_conditions/1)
    enriched_validation = Enum.map(implementation.validation, &enrich_conditions/1)
    enriched_segments = Enum.map(implementation.segments, &enrich_condition/1)
    enriched_data_structures = maybe_preload_structure(implementation, preload_structure)

    implementation
    |> Map.put(:dataset, enriched_dataset)
    |> Map.put(:populations, enriched_populations)
    |> Map.put(:validation, enriched_validation)
    |> Map.put(:segments, enriched_segments)
    |> Map.put(:data_structures, enriched_data_structures)
  end

  defp enrich_implementation_structure(%{id: id, type: "reference_dataset"} = structure)
       when not is_nil(id) do
    if ReferenceData.exists?(id) do
      id
      |> ReferenceData.get!()
      |> Map.take([:id, :name, :headers])
      |> Map.put(:type, "reference_dataset")
    else
      structure
    end
  end

  defp enrich_implementation_structure(%{id: id} = structure) when not is_nil(id) do
    cached_structure = StructureEntry.cache_entry(id, system: true)
    put_structure_cached_attributes(structure, cached_structure)
  end

  defp enrich_implementation_structure(structure), do: structure

  defp maybe_preload_structure(implementation, true) do
    implementation
    |> Repo.preload(
      implementation_ref_struct: [
        data_structures: [data_structure: [:system, :current_version]]
      ],
      data_structures: []
    )
    |> enrich_data_structures_path()
    |> Enum.map(&enrich_domains(&1))
  end

  defp maybe_preload_structure(
         %{implementation_ref_struct: %{data_structures: data_structures}},
         _
       )
       when is_list(data_structures),
       do: data_structures

  defp maybe_preload_structure(
         %{implementation_ref_struct: %{data_structures: _data_structures}},
         _
       ),
       do: []

  defp enrich_domains(
         %{data_structure: %DataStructure{domain_ids: [_ | _] = domain_ids} = structure} =
           implementation_structure
       ) do
    domains =
      Enum.map(domain_ids, fn domain_id ->
        case TaxonomyCache.get_domain(domain_id) do
          %{} = domain ->
            Map.put(domain, :parents, StructureEnricher.get_domain_parents(domain.id))

          nil ->
            %{}
        end
      end)

    Map.put(implementation_structure, :data_structure, %{structure | domains: domains})
  end

  defp enrich_domains(implementation_structure), do: implementation_structure

  defp enrich_dataset_row(%{structure: structure} = dataset_row) do
    enriched_structure = enrich_implementation_structure(structure)

    dataset_row
    |> Map.put(:structure, enriched_structure)
    |> enrich_joined_structures
  end

  defp enrich_dataset_row(dataset_row), do: dataset_row

  defp enrich_data_structures_path(%{
         implementation_ref_struct: %{data_structures: [_ | _] = data_structures}
       }) do
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

  defp enrich_conditions(%{conditions: conditions} = conditions_list) do
    %{conditions_list | conditions: Enum.map(conditions, &enrich_condition/1)}
  end

  defp enrich_conditions(conditions), do: conditions

  defp enrich_condition(%{structure: structure = %{}} = condition) do
    enriched_structure = enrich_implementation_structure(structure)

    condition
    |> Map.put(:structure, enriched_structure)
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

  defp enrich_clause_structures(%{left: left, right: right} = structure_map) do
    structure_map
    |> Map.put(:left, enrich_implementation_structure(left))
    |> Map.put(:right, enrich_implementation_structure(right))
  end

  defp enrich_value_structure(%{"id" => id, "type" => "reference_dataset_field"} = value_map) do
    value_map_atom = for {key, val} <- value_map, into: %{}, do: {String.to_atom(key), val}

    if ReferenceData.exists?(id) do
      ReferenceData.Dataset
      |> Repo.get!(id)
      |> Map.from_struct()
      |> Map.take([:name, :id])
      |> Map.merge(value_map_atom)
    else
      value_map
    end
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
      |> Map.put(:name, Map.get(cached_info, :original_name, Map.get(structure_map, :name, "")))
      |> Map.put(:path, Map.get(cached_info, :path, []))
      |> Map.put(:system, Map.get(cached_info, :system))
      |> Map.put(:type, Map.get(cached_info, :type))
      |> maybe_put_alias(cached_info)

    case Map.get(cached_info, :metadata) do
      nil -> structure_map
      metadata -> Map.put(structure_map, :metadata, metadata)
    end
  end

  defp maybe_put_alias(%{} = map, %{name: alias_name, original_name: original_name})
       when original_name != alias_name,
       do: Map.put(map, :alias, alias_name)

  defp maybe_put_alias(%{} = map, _), do: map

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
    do: [Map.take(left, [:id, :name, :type]), Map.take(right, [:id, :name, :type])]

  defp structure(%{value: value}), do: structure(value)

  defp structure(%{id: _id} = structure),
    do: [Map.take(structure, [:id, :name, :type])]

  defp structure(%{"id" => id} = structure) do
    name = Map.get(structure, "name")
    type = Map.get(structure, "type")
    [%{id: id, name: name, type: type}]
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

    result = RuleResults.get_latest_rule_result(implementation)

    execution_result_info =
      Implementation.get_execution_result_info(implementation, result, quality_event)

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

  def get_implementation_links(%Implementation{implementation_ref: id}) do
    case LinkCache.list("implementation_ref", id) do
      {:ok, links} -> links
    end
  end

  def get_implementation_links(%Implementation{implementation_ref: id}, target_type) do
    case LinkCache.list("implementation_ref", id, target_type) do
      {:ok, links} -> links
    end
  end

  def get_implementation_structure!(implementation_structure_id, preloads \\ []) do
    ImplementationStructure
    |> where([is], is_nil(is.deleted_at))
    |> Repo.get!(implementation_structure_id)
    |> Repo.preload(preloads)
  end

  def get_implementation_by_structure_ids(structures_ids) do
    ImplementationStructure
    |> where([is], is.data_structure_id in ^structures_ids)
    |> Repo.all()
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
    implementation_ref =
      implementation
      |> Repo.preload(:implementation_ref_struct)
      |> Map.get(:implementation_ref_struct)

    %ImplementationStructure{}
    |> ImplementationStructure.changeset(
      attrs,
      implementation_ref,
      data_structure
    )
    |> Repo.insert(opts)
    |> case do
      {:error, _} = error ->
        error

      implementation_structure ->
        implementations_ids = get_implementation_versions_ids_by_ref(implementation_ref.id)
        IndexWorker.reindex(:implementations, implementations_ids)
        implementation_structure
    end
  end

  def delete_implementation_structure(%ImplementationStructure{} = implementation_structure) do
    implementation_structure
    |> ImplementationStructure.delete_changeset()
    |> Repo.update()
    |> case do
      {:error, _} = error ->
        error

      deleted_implementation_structure ->
        implementations_ids =
          get_implementation_versions_ids_by_ref(implementation_structure.implementation_id)

        IndexWorker.reindex(:implementations, implementations_ids)
        deleted_implementation_structure
    end
  end

  def reindex_implementations_structures(structures_ids) do
    implementations_ids =
      structures_ids
      |> get_implementation_by_structure_ids()
      |> Enum.map(&Map.get(&1, :implementation_id))

    if implementations_ids !== [] do
      IndexWorker.reindex(:implementations, implementations_ids)
    else
      :ok
    end
  end

  def get_implementation_versions_ids_by_ref(implementation_ref) do
    Implementation
    |> where([i], i.implementation_ref == ^implementation_ref)
    |> Repo.all()
    |> Enum.map(&Map.get(&1, :id))
  end

  def get_cached_content(%{} = content, type) when is_binary(type) do
    case TemplateCache.get_by_name!(type) do
      template = %{} -> Format.enrich_content_values(content, template, [:system, :hierarchy])
      _ -> content
    end
  end

  def get_cached_content(content, _type), do: content

  ## Dataloader
  def datasource do
    timeout = Application.get_env(:td_dd, TdDd.Repo)[:timeout]
    Dataloader.Ecto.new(TdDd.Repo, query: &query/2, timeout: timeout)
  end

  defp query(queryable, params) do
    Enum.reduce(params, queryable, fn
      {:preload, preload}, q -> preload(q, ^preload)
    end)
  end
end
