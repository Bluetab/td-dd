defmodule TdDq.Rules do
  @moduledoc """
  The Rules context.
  """

  import Ecto.Query, warn: false

  alias Ecto.Changeset
  alias Ecto.Multi
  alias TdCache.ConceptCache
  alias TdCache.EventStream.Publisher
  alias TdCache.StructureCache
  alias TdCache.TemplateCache
  alias TdDfLib.Validation
  alias TdDq.Cache.RuleLoader
  alias TdDq.Repo
  alias TdDq.Rules.Rule
  alias TdDq.Rules.RuleImplementation
  alias TdDq.Rules.RuleResult

  require Logger

  @doc """
  Returns the list of rules.

  ## Examples

      iex> list_rules()
      [%Rule{}, ...]

  """
  def list_rules(params \\ %{})

  def list_rules(rule_ids) when is_list(rule_ids) do
    Rule
    |> where([r], is_nil(r.deleted_at))
    |> where([r], r.id in ^rule_ids)
    |> Repo.all()
  end

  def list_rules(params) do
    fields = Rule.__schema__(:fields)
    dynamic = filter(params, fields)

    query =
      from(
        p in Rule,
        where: ^dynamic,
        where: is_nil(p.deleted_at)
      )

    query
    |> Repo.all()
  end

  def list_rules_with_bc_id do
    Rule
    |> where([r], is_nil(r.deleted_at))
    |> where([r], not is_nil(r.business_concept_id))
    |> Repo.all()
    |> Enum.map(&preload_bc_version/1)
  end

  def list_all_rules do
    Rule
    |> where([r], is_nil(r.deleted_at))
    |> Repo.all()
    |> Enum.map(&preload_bc_version/1)
  end

  defp preload_bc_version(%{business_concept_id: nil} = rule), do: rule

  defp preload_bc_version(%{business_concept_id: business_concept_id} = rule) do
    case ConceptCache.get(business_concept_id) do
      {:ok, %{name: name, business_concept_version_id: id}} ->
        Map.put(rule, :current_business_concept_version, %{name: name, id: id})

      _ ->
        rule
    end
  end

  defp preload_bc_version(rule), do: rule

  @doc """
  Gets a single rule.

  Raises `Ecto.NoResultsError` if the Quality control does not exist.

  ## Examples

      iex> get_rule!(123)
      %Rule{}

      iex> get_rule!(456)
      ** (Ecto.NoResultsError)

  """
  def get_rule!(id) do
    Rule
    |> where([r], is_nil(r.deleted_at))
    |> Repo.get!(id)
  end

  @doc """
  Gets a single rule.

  ## Examples

      iex> get_rule(123)
      %Rule{}

      iex> get_rule(456)
      ** nil

  """
  def get_rule(id) do
    Rule
    |> where([r], is_nil(r.deleted_at))
    |> Repo.get(id)
  end

  @doc """
  Creates a rule.

  ## Examples

      iex> create_rule(%{field: value})
      {:ok, %Rule{}}

      iex> create_rule(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_rule(attrs \\ %{}) do
    with {:ok, changeset} <- check_base_changeset(attrs),
         {:ok} <- check_dynamic_form_changeset(attrs),
         {:ok, rule} <- Repo.insert(changeset) do
      rule =
        rule
        |> preload_bc_version

      RuleLoader.refresh(Map.get(rule, :id))

      {:ok, rule}
    else
      error -> error
    end
  end

  defp check_base_changeset(attrs, rule \\ %Rule{}) do
    changeset = Rule.changeset(rule, attrs)

    case changeset.valid? do
      true -> {:ok, changeset}
      false -> {:error, changeset}
    end
  end

  defp check_dynamic_form_changeset(%{"df_name" => df_name} = attrs) when not is_nil(df_name) do
    content = Map.get(attrs, "df_content", %{})
    %{:content => content_schema} = TemplateCache.get_by_name!(df_name)
    content_changeset = Validation.build_changeset(content, content_schema)

    case content_changeset.valid? do
      true -> {:ok}
      false -> {:error, content_changeset}
    end
  end

  defp check_dynamic_form_changeset(_), do: {:ok}

  @doc """
  Updates a rule.

  ## Examples

      iex> update_rule(rule, %{field: new_value})
      {:ok, %Rule{}}

      iex> update_rule(rule, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_rule(%Rule{} = rule, attrs) do
    with {:ok, changeset} <- check_base_changeset(attrs, rule),
         {:ok} <- check_dynamic_form_changeset(attrs) do
      do_update_rule(changeset)
    else
      error -> error
    end
  end

  defp do_update_rule(changeset) do
    with {:ok, rule} <- Repo.update(changeset) do
      rule =
        rule
        |> preload_bc_version

      RuleLoader.refresh(Map.get(rule, :id))
      {:ok, rule}
    else
      error -> error
    end
  end

  @doc """
  Deletes a Rule.

  ## Examples

      iex> delete_rule(rule)
      {:ok, %Rule{}}

      iex> delete_rule(rule)
      {:error, %Ecto.Changeset{}}

  """
  def delete_rule(%Rule{id: id} = rule) do
    case do_delete_rule(rule) do
      {:ok, rule} ->
        RuleLoader.delete(id)

        {:ok, rule}

      error ->
        error
    end
  end

  defp do_delete_rule(%Rule{} = rule) do
    rule
    |> Rule.delete_changeset()
    |> Repo.delete()
  end

  def soft_deletion(active_ids, ts \\ DateTime.utc_now()) do
    case do_soft_deletion(active_ids, ts) do
      {:ok, %{rules: {_, rule_ids}} = results} ->
        RuleLoader.delete(rule_ids)

        {:ok, results}

      error ->
        error
    end
  end

  defp do_soft_deletion(active_ids, ts) do
    rules_to_delete =
      Rule
      |> where([r], not is_nil(r.business_concept_id))
      |> where([r], is_nil(r.deleted_at))
      |> where([r], r.business_concept_id not in ^active_ids)
      |> select([r], r.id)

    impls_to_delete =
      RuleImplementation
      |> join(:inner, [ri], r in assoc(ri, :rule))
      |> where([_, r], not is_nil(r.business_concept_id))
      |> where([_, r], is_nil(r.deleted_at))
      |> where([_, r], r.business_concept_id not in ^active_ids)
      |> select([ri, _], ri.id)

    Multi.new()
    |> Multi.update_all(:impls, impls_to_delete, set: [deleted_at: ts])
    |> Multi.update_all(:rules, rules_to_delete, set: [deleted_at: ts])
    |> Repo.transaction()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking rule changes.

  ## Examples

      iex> change_rule(rule)
      %Ecto.Changeset{source: %Rule{}}

  """
  def change_rule(%Rule{} = rule) do
    Rule.changeset(rule, %{})
  end

  def list_concept_rules(params) do
    fields = Rule.__schema__(:fields)
    dynamic = filter(params, fields)

    query =
      from(
        p in Rule,
        where: ^dynamic,
        where: is_nil(p.deleted_at),
        order_by: [desc: :business_concept_id]
      )

    query |> Repo.all()
  end

  def get_rule_implementation_results(implementation_key) do
    RuleResult
    |> where([r], r.implementation_key == ^implementation_key)
    |> order_by(desc: :date)
    |> Repo.all()
  end

  @doc """
  Returns the list of rule_implementations.

  ## Examples

      iex> list_rule_implementations(params, opts)
      [%RuleImplementation{}, ...]

  """
  def list_rule_implementations(params \\ %{}, opts \\ [])

  def list_rule_implementations(%{"structure_id" => structure_id}, _opts) do
    condition =
      dynamic(
        [ri],
        fragment(
          "exists (select * from unnest(?) obj where (obj->'structure'->>'id')::int = ?)",
          ri.dataset,
          ^structure_id
        ) or false
      )

    condition =
      dynamic(
        [ri],
        fragment(
          "exists (select * from unnest(?) obj where (obj->'structure'->>'id')::int = ?)",
          ri.validations,
          ^structure_id
        ) or ^condition
      )

    RuleImplementation
    |> where(^condition)
    |> Repo.all()
  end

  def list_rule_implementations(params, opts) do
    rule_params = Map.get(params, :rule) || Map.get(params, "rule", %{})
    rule_fields = Rule.__schema__(:fields)
    dynamic = filter(params, RuleImplementation.__schema__(:fields))
    dynamic = dynamic_rule_params(rule_params, rule_fields, dynamic)

    RuleImplementation
    |> join(:inner, [ri], r in assoc(ri, :rule))
    |> where(^dynamic)
    |> where([_ri, r], is_nil(r.deleted_at))
    |> deleted_implementations(opts, :implementations)
    |> Repo.all()
  end

  @doc """
  Gets a single rule_implementation.

  Raises `Ecto.NoResultsError` if the Rule does not exist.

  ## Examples

      iex> get_rule_implementation!(123)
      %RuleImplementation{}

      iex> get_rule_implementation!(456)
      ** (Ecto.NoResultsError)

  """
  def get_rule_implementation!(id) do
    RuleImplementation
    |> join(:inner, [ri], r in assoc(ri, :rule))
    |> where([_, r], is_nil(r.deleted_at))
    |> Repo.get!(id)
  end

  def get_rule_by_implementation_key(implementation_key) do
    implementation_rule =
      implementation_key
      |> get_rule_implementation_by_key()
      |> Repo.preload(:rule)

    case implementation_rule do
      nil -> nil
      _rule -> Map.get(implementation_rule, :rule)
    end
  end

  @doc """
  Gets a single rule_implementation.

  Returns nil if the Rule does not exist.

  ## Examples

      iex> get_rule_implementation!(123)
      %RuleImplementation{}

      iex> get_rule_implementation!(456)
      nil

  """
  def get_rule_implementation(id) do
    RuleImplementation
    |> join(:inner, [ri], r in assoc(ri, :rule))
    |> where([_, r], is_nil(r.deleted_at))
    |> Repo.get(id)
  end

  def get_rule_implementation_by_key(implementation_key) do
    RuleImplementation
    |> join(:inner, [ri], r in assoc(ri, :rule))
    |> where([_, r], is_nil(r.deleted_at))
    |> where([ri, _], is_nil(ri.deleted_at))
    |> Repo.get_by(implementation_key: implementation_key)
  end

  @doc """
  Creates a rule_implementation.

  ## Examples

      iex> create_rule_implementation(%{field: value})
      {:ok, %RuleImplementation{}}

      iex> create_rule_implementation(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_rule_implementation(rule, attrs \\ %{}) do
    changeset = RuleImplementation.changeset(%RuleImplementation{rule: rule}, attrs)

    case changeset.valid? do
      true ->
        insert_rule_implementation(changeset)

      false ->
        errors =
          Changeset.traverse_errors(changeset, fn {_msg, opts} ->
            "#{Keyword.get(opts, :validation)}"
          end)

        {:error, changeset, errors}
    end
  end

  defp put_structure_cached_attributes(structure_map, cached_info) do
    structure_map
    |> Map.put(:external_id, Map.get(cached_info, :external_id))
    |> Map.put(:name, Map.get(cached_info, :name, Map.get(structure_map, :name, "")))
    |> Map.put(:path, Map.get(cached_info, :path, []))
    |> Map.put(:system, Map.get(cached_info, :system))
    |> Map.put(:type, Map.get(cached_info, :type))
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

  defp enrich_value_structures(population_row) do
    values = Map.get(population_row, :value)

    case values do
      nil ->
        population_row

      _ ->
        values =
          Enum.map(values, fn value ->
            enrich_value_structure(value)
          end)

        Map.put(population_row, :value, values)
    end
  end

  def enrich_rule_implementation_structures(%RuleImplementation{} = rule_implementation) do
    enriched_dataset =
      Enum.map(rule_implementation.dataset, fn dataset_row ->
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
      Enum.map(rule_implementation.population, fn population_row ->
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
      Enum.map(rule_implementation.validations, fn validations_row ->
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

    rule_implementation
    |> Map.put(:dataset, enriched_dataset)
    |> Map.put(:population, enriched_population)
    |> Map.put(:validations, enriched_validations)
  end

  defp read_structure_from_cache(structure_id) do
    {:ok, structure} = StructureCache.get(structure_id)

    case structure do
      nil -> %{}
      _ -> structure
    end
  end

  defp insert_rule_implementation(changeset) do
    result =
      changeset
      |> Repo.insert()

    case result do
      {:ok, rule_implementation} ->
        add_rule_implementation_structure_links(rule_implementation)

      _ ->
        result
    end

    result
  end

  defp get_dataset_row_ids(%{clauses: clauses}) do
    Enum.flat_map(clauses, &get_join_clause_ids/1)
  end

  defp get_dataset_row_ids(_structure) do
    []
  end

  defp get_join_clause_ids(%{left: %{id: left_id}, right: %{id: right_id}}) do
    [left_id, right_id]
  end

  defp get_join_clause_ids(_) do
    []
  end

  defp get_value_id(%{"id" => value_id}) do
    value_id
  end

  defp get_value_id(_value) do
    nil
  end

  defp get_filters_value_ids(values) when is_list(values) do
    Enum.map(values, fn value ->
      get_value_id(value)
    end)
  end

  defp get_filters_value_ids(_other) do
    []
  end

  defp get_structure_id(%{structure: %{id: id}}) do
    id
  end

  defp get_structure_id(_any) do
    nil
  end

  def get_structures_ids(%RuleImplementation{} = rule_implementation) do
    dataset_ids =
      rule_implementation
      |> Map.get(:dataset)
      |> Enum.map(fn dataset_row ->
        [get_structure_id(dataset_row)] ++ get_dataset_row_ids(dataset_row)
      end)

    population_ids =
      rule_implementation
      |> Map.get(:population)
      |> Enum.map(fn structure ->
        [get_structure_id(structure)] ++ get_filters_value_ids(Map.get(structure, :value))
      end)

    validations_ids =
      rule_implementation
      |> Map.get(:validations)
      |> Enum.map(fn structure ->
        [get_structure_id(structure)] ++ get_filters_value_ids(Map.get(structure, :value))
      end)

    ids = dataset_ids ++ population_ids ++ validations_ids

    ids
    |> List.flatten()
    |> Enum.filter(&(not is_nil(&1)))
  end

  def add_rule_implementation_structure_links(%RuleImplementation{} = rule_implementation) do
    rule_implementation
    |> get_structures_ids()
    |> Enum.uniq()
    |> Enum.map(&add_rule_implementation_structure_link/1)
  end

  def add_rule_implementation_structure_link(structure_id) do
    Publisher.publish(
      %{
        event: "add_rule_implementation_link",
        structure_id: structure_id
      },
      "data_structure:events"
    )
  end

  @doc """
  Updates a rule_implementation.

  ## Examples

      iex> update_rule_implementation(rule_implementation, %{field: new_value})
      {:ok, %RuleImplementation{}}

      iex> update_rule_implementation(rule_implementation, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_rule_implementation(%RuleImplementation{} = rule_implementation, attrs) do
    changeset = RuleImplementation.changeset(rule_implementation, attrs)

    case changeset.valid? do
      true ->
        case true do
          true -> update_rule_implementation(changeset)
          false -> {:error, changeset}
        end

      false ->
        {:error, changeset}
    end
  end

  defp update_rule_implementation(changeset) do
    result = changeset |> Repo.update()

    case result do
      {:ok, rule_implementation} ->
        add_rule_implementation_structure_links(rule_implementation)

      _ ->
        result
    end

    result
  end

  @doc """
  Deletes a RuleImplementation.

  ## Examples

      iex> delete_rule_implementation(rule_implementation, opts)
      {:ok, %RuleImplementation{}}

      iex> delete_rule_implementation(rule_implementation, opts)
      {:error, %Ecto.Changeset{}}

  """
  def delete_rule_implementation(%RuleImplementation{} = rule_implementation) do
    reply = Repo.delete(rule_implementation)
    RuleLoader.refresh(Map.get(rule_implementation, :rule_id))
    reply
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking rule_implementation changes.

  ## Examples

      iex> change_rule_implementation(rule_implementation)
      %Ecto.Changeset{source: %RuleImplementation{}}

  """
  def change_rule_implementation(%RuleImplementation{} = rule_implementation) do
    RuleImplementation.changeset(rule_implementation, %{})
  end

  def get_rule_or_nil(id) when is_nil(id) or id == "", do: nil
  def get_rule_or_nil(id), do: get_rule(id)

  defp filter(params, fields) do
    dynamic = true

    Enum.reduce(Map.keys(params), dynamic, fn key, acc ->
      key_as_atom = binary_to_atom(key)

      case Enum.member?(fields, key_as_atom) and !is_map(Map.get(params, key)) do
        true -> dynamic([p], field(p, ^key_as_atom) == ^params[key] and ^acc)
        false -> acc
      end
    end)
  end

  def check_available_implementation_key(%{"implementation_key" => ""}),
    do: {:implementation_key_available}

  def check_available_implementation_key(%{"implementation_key" => implementation_key}) do
    count =
      RuleImplementation
      |> where([ri], ri.implementation_key == ^implementation_key)
      |> Repo.all()

    if Enum.empty?(count),
      do: {:implementation_key_available},
      else: {:implementation_key_not_available}
  end

  alias TdDq.Rules.RuleResult

  @doc """
  Creates a rule_result.

  ## Examples

      iex> create_rule_result(%{field: value})
      {:ok, %RuleResult{}}

      iex> create_rule_result(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_rule_result(attrs \\ %{}) do
    %RuleResult{}
    |> RuleResult.changeset(attrs)
    |> Repo.insert()
  end

  def list_rule_results do
    RuleResult
    |> join(:inner, [rr, ri], ri in RuleImplementation,
      on: rr.implementation_key == ri.implementation_key
    )
    |> join(:inner, [_, ri, r], r in Rule, on: r.id == ri.rule_id)
    |> where([_, _, r], is_nil(r.deleted_at))
    |> where([_, ri, _], is_nil(ri.deleted_at))
    |> Repo.all()
  end

  def list_rule_results(ids) do
    RuleResult
    |> join(:inner, [rr, ri], ri in RuleImplementation,
      on: rr.implementation_key == ri.implementation_key
    )
    |> join(:inner, [_, ri, r], r in Rule, on: r.id == ri.rule_id)
    |> where([rr, _, _], rr.id in ^ids)
    |> where([_, _, r], not is_nil(r.business_concept_id))
    |> where([_, _, r], is_nil(r.deleted_at))
    |> where([_, ri, _], is_nil(ri.deleted_at))
    |> where(
      [rr, _, r],
      (r.result_type == ^Rule.result_type().percentage and rr.result < r.minimum) or
        (r.result_type == ^Rule.result_type().errors_number and rr.errors > r.goal)
    )
    |> select([rr, _, r], %{
      id: rr.id,
      date: rr.date,
      implementation_key: rr.implementation_key,
      rule_id: r.id,
      result: rr.result,
      inserted_at: rr.inserted_at
    })
    |> Repo.all()
  end

  @doc """
  Returns last rule_result for each rule_implementation of rule
  """
  def get_latest_rule_results(%Rule{} = rule) do
    rule
    |> Repo.preload(:rule_implementations)
    |> Map.get(:rule_implementations)
    |> Enum.map(&get_latest_rule_result(&1.implementation_key))
    |> Enum.filter(& &1)
  end

  def get_latest_rule_result(implementation_key) do
    RuleResult
    |> where([r], r.implementation_key == ^implementation_key)
    |> join(:inner, [r, ri], ri in RuleImplementation,
      on: r.implementation_key == ri.implementation_key
    )
    |> order_by(desc: :date)
    |> limit(1)
    |> Repo.one()
  end

  defp dynamic_rule_params(params, fields, dynamic) do
    names = Map.keys(params)

    Enum.reduce(names, dynamic, fn name, acc ->
      atom_name = binary_to_atom(name)

      case Enum.member?(fields, atom_name) do
        false ->
          acc

        true ->
          params
          |> Map.get(name)
          |> dynamic_filter(atom_name, acc)
      end
    end)
  end

  defp binary_to_atom(value), do: if(is_binary(value), do: String.to_atom(value), else: value)

  defp dynamic_filter(field, atom_name, acc) when is_map(field) do
    dynamic([_, p], fragment("(?) @> ?::jsonb", field(p, ^atom_name), ^field) and ^acc)
  end

  defp dynamic_filter(field, atom_name, acc) do
    dynamic([_, p], field(p, ^atom_name) == ^field and ^acc)
  end

  defp deleted_implementations(query, options, order) do
    case Keyword.get(options, :deleted, false) do
      true ->
        with_deleted(query, order)

      false ->
        without_deleted(query, order)
    end
  end

  defp with_deleted(query, :implementations) do
    where(query, [ri, _r], not is_nil(ri.deleted_at))
  end

  defp with_deleted(query, :results) do
    where(query, [_r, ri], not is_nil(ri.deleted_at))
  end

  defp without_deleted(query, :implementations) do
    where(query, [ri, _r], is_nil(ri.deleted_at))
  end

  defp without_deleted(query, :results) do
    where(query, [_r, ri], is_nil(ri.deleted_at))
  end
end
