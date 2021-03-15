defmodule TdDq.Rules.Implementations do
  @moduledoc """
  The Rule Implementations context.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias TdCache.StructureCache
  alias TdDq.Auth.Claims
  alias TdDq.Cache.ImplementationLoader
  alias TdDq.Cache.RuleLoader
  alias TdDq.Repo
  alias TdDq.Rules.Audit
  alias TdDq.Rules.Implementations.ConditionRow
  alias TdDq.Rules.Implementations.DatasetRow
  alias TdDq.Rules.Implementations.Implementation
  alias TdDq.Rules.Implementations.Structure
  alias TdDq.Rules.Rule
  alias TdDq.Search.IndexWorker

  @doc """
  Gets a single implementation.

  Raises `Ecto.NoResultsError` if the Rule does not exist.

  ## Examples

      iex> get_implementation!(123)
      %Implementation{}

      iex> get_implementation!(456)
      ** (Ecto.NoResultsError)

  """
  def get_implementation!(id) do
    Implementation
    |> join(:inner, [ri], r in assoc(ri, :rule))
    |> where([_, r], is_nil(r.deleted_at))
    |> Repo.get!(id)
  end

  def get_implementation_by_key(implementation_key, deleted \\ nil)

  def get_implementation_by_key(implementation_key, true) do
    Implementation
    |> join(:inner, [ri], r in assoc(ri, :rule))
    |> Repo.get_by(implementation_key: implementation_key)
  end

  def get_implementation_by_key(implementation_key, _deleted) do
    Implementation
    |> join(:inner, [ri], r in assoc(ri, :rule))
    |> where([_, r], is_nil(r.deleted_at))
    |> where([ri, _], is_nil(ri.deleted_at))
    |> Repo.get_by(implementation_key: implementation_key)
  end

  @doc """
  Creates an implementation.

  ## Examples

      iex> create_implementation(rule, %{field: value})
      {:ok, %Implementation{}}

      iex> create_implementation(rule, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_implementation(%{id: rule_id} = _rule, params \\ %{}) do
    %Implementation{rule_id: rule_id}
    |> Implementation.changeset(params)
    |> Repo.insert()
    |> on_upsert()
  end

  @doc """
  Updates an implementation.

  ## Examples

      iex> update_implementation(implementation, %{field: new_value}, claims)
      {:ok, %Implementation{}}

      iex> update_implementation(implementation, %{field: bad_value}, claims)
      {:error, %Ecto.Changeset{}}

  """
  def update_implementation(%Implementation{} = implementation, params, %Claims{user_id: user_id}) do
    changeset = Implementation.changeset(implementation, params)

    Multi.new()
    |> Multi.update(:implementation, changeset)
    |> Multi.run(:audit, Audit, :implementation_updated, [changeset, user_id])
    |> Repo.transaction()
    |> on_upsert()
  end

  @spec deprecate_implementations ::
          :ok | {:ok, map} | {:error, Multi.name(), any, %{required(Multi.name()) => any}}
  def deprecate_implementations do
    deleted_structure_ids = StructureCache.deleted_ids() |> MapSet.new()

    list_implementations()
    |> Enum.map(fn impl -> {impl, get_structure_ids(impl)} end)
    |> Enum.reject(fn {_, ids} -> MapSet.disjoint?(deleted_structure_ids, MapSet.new(ids)) end)
    |> Enum.map(fn {%{id: id}, _} -> id end)
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
    |> Multi.update_all(:deprecated, query, set: [deleted_at: ts])
    |> Multi.run(:audit, Audit, :implementations_deprecated, [])
    |> Repo.transaction()
    |> on_deprecate()
  end

  defp on_deprecate(result) do
    case result do
      {:ok, %{deprecated: {_, [_ | _] = impls}}} ->
        impls
        |> Enum.map(& &1.id)
        |> IndexWorker.reindex_implementations()

        result

      _ ->
        result
    end
  end

  @doc """
  Deletes an implementation.

  ## Examples

      iex> delete_implementation(implementation, opts)
      {:ok, %Implementation{}}

      iex> delete_implementation(implementation, opts)
      {:error, %Ecto.Changeset{}}

  """
  def delete_implementation(%Implementation{id: id} = implementation) do
    reply = Repo.delete(implementation)
    RuleLoader.refresh(Map.get(implementation, :rule_id))
    IndexWorker.delete_implementations(id)
    reply
  end

  defp on_upsert({:ok, %{implementation: implementation}} = result) do
    id = Map.get(implementation, :id)
    ImplementationLoader.refresh(id)
    IndexWorker.reindex_implementations(id)
    result
  end

  defp on_upsert(result) do
    with {:ok, implementation} <- result do
      IndexWorker.reindex_implementations(Map.get(implementation, :id))
      result
    end
  end

  def get_sources(%Implementation{} = implementation) do
    implementation
    |> get_structure_ids()
    |> Search.Helpers.get_sources()
  end

  def get_structure_ids(%Implementation{} = implementation) do
    implementation
    |> Map.take([:dataset, :population, :validations])
    |> Map.values()
    |> Enum.flat_map(&structure_ids/1)
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
    |> Repo.all()
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

  def enrich_implementation_structures(%Implementation{} = implementation) do
    enriched_dataset =
      Enum.map(implementation.dataset, fn dataset_row ->
        case dataset_row |> Map.get(:structure) |> Map.get(:id) do
          nil ->
            dataset_row

          id ->
            cached_structure = read_structure_from_cache(id)

            dataset_row
            |> Map.put(
              :structure,
              put_structure_cached_attributes(Map.get(dataset_row, :structure), cached_structure)
            )
            |> enrich_joined_structures
        end
      end)

    enriched_population =
      Enum.map(implementation.population, fn population_row ->
        case Map.get(population_row, :structure) do
          nil ->
            population_row

          structure ->
            cached_structure = read_structure_from_cache(Map.get(structure, :id))

            enriched_info =
              population_row
              |> Map.get(:structure)
              |> put_structure_cached_attributes(cached_structure)

            population_row
            |> Map.put(:structure, enriched_info)
            |> enrich_value_structures()
        end
      end)

    enriched_validations =
      Enum.map(implementation.validations, fn validations_row ->
        case Map.get(validations_row, :structure) do
          nil ->
            validations_row

          structure ->
            cached_structure = read_structure_from_cache(Map.get(structure, :id))

            enriched_info =
              validations_row
              |> Map.get(:structure)
              |> put_structure_cached_attributes(cached_structure)

            validations_row
            |> Map.put(:structure, enriched_info)
            |> enrich_value_structures()
        end
      end)

    implementation
    |> Map.put(:dataset, enriched_dataset)
    |> Map.put(:population, enriched_population)
    |> Map.put(:validations, enriched_validations)
  end

  def read_structure_from_cache(structure_id) do
    {:ok, structure} = StructureCache.get(structure_id)

    case structure do
      nil -> %{}
      _ -> structure
    end
  end

  defp enrich_joined_structures(%{clauses: clauses} = structure_map) when is_list(clauses) do
    clauses = Enum.map(clauses, &enrich_clause_structures/1)
    Map.put(structure_map, :clauses, clauses)
  end

  defp enrich_joined_structures(structure_map) do
    structure_map
  end

  defp enrich_clause_structures(%{left: %{id: left_id}, right: %{id: right_id}} = structure_map) do
    structure_map
    |> Map.put(
      :left,
      put_structure_cached_attributes(%{id: left_id}, read_structure_from_cache(left_id))
    )
    |> Map.put(
      :right,
      put_structure_cached_attributes(%{id: right_id}, read_structure_from_cache(right_id))
    )
  end

  defp enrich_value_structure(%{"id" => id} = value_map) do
    cached_structure = read_structure_from_cache(id)
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

  defp structure_ids([_ | _] = values), do: Enum.flat_map(values, &structure_ids/1)
  defp structure_ids(%Structure{id: id}), do: [id]

  defp structure_ids(%ConditionRow{structure: structure, value: nil}),
    do: structure_ids(structure)

  defp structure_ids(%ConditionRow{structure: structure, value: values}),
    do: structure_ids([structure | values])

  defp structure_ids(%DatasetRow{structure: structure, clauses: nil}),
    do: structure_ids(structure)

  defp structure_ids(%DatasetRow{structure: structure, clauses: clauses}),
    do: structure_ids([structure | clauses])

  defp structure_ids(%{left: %{id: left_id}, right: %{id: right_id}}), do: [left_id, right_id]
  defp structure_ids(%{value: value}), do: structure_ids(value)
  defp structure_ids(%{"id" => id}), do: [id]
  defp structure_ids(_any), do: []
end
