defmodule TdDq.Rules do
  @moduledoc """
  The Rules context.
  """

  import Ecto.Query, warn: false

  alias Ecto.Changeset
  alias Ecto.Multi
  alias TdCache.ConceptCache
  alias TdCache.EventStream.Publisher
  alias TdCache.LinkCache
  alias TdCache.StructureCache
  alias TdCache.TemplateCache
  alias TdDfLib.Validation
  alias TdDq.Cache.RuleLoader
  alias TdDq.Repo
  alias TdDq.Rules.Rule
  alias TdDq.Rules.RuleImplementation
  alias TdDq.Rules.RuleResult
  alias TdDq.Rules.RuleType

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
    |> Repo.preload(:rule_type)
  end

  def list_rules_with_bc_id do
    Rule
    |> where([r], is_nil(r.deleted_at))
    |> where([r], not is_nil(r.business_concept_id))
    |> Repo.all()
    |> Repo.preload(:rule_type)
    |> Enum.map(&preload_bc_version/1)
  end

  def list_all_rules do
    Rule
    |> where([r], is_nil(r.deleted_at))
    |> Repo.all()
    |> Repo.preload(:rule_type)
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
  def create_rule(rule_type, attrs \\ %{}) do
    with {:ok, changeset} <- check_base_changeset(attrs),
         {:ok} <- check_dynamic_form_changeset(attrs),
         {:ok} <- check_rule_type_changeset(changeset, rule_type),
         {:ok, rule} <- Repo.insert(changeset) do
      rule =
        rule
        |> Repo.preload(:rule_type)
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

  defp check_rule_type_changeset(changeset, rule_type) do
    input = Changeset.get_change(changeset, :type_params)
    types = get_type_params_or_nil(rule_type)

    type_changeset =
      types
      |> rule_type_changeset(input)
      |> add_rule_type_params_validations(rule_type, types)

    case type_changeset.valid? do
      true -> {:ok}
      false -> {:error, type_changeset}
    end
  end

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
      input = Map.get(attrs, :type_params) || Map.get(attrs, "type_params", %{})
      rule_type = Repo.preload(rule, :rule_type).rule_type
      types = get_type_params_or_nil(rule_type)

      type_changeset =
        types
        |> rule_type_changeset(input)
        |> add_rule_type_params_validations(rule_type, types)

      non_modifiable_changeset =
        type_changeset
        |> validate_non_modifiable_fields(attrs)

      case non_modifiable_changeset.valid? do
        true -> do_update_rule(changeset)
        false -> {:error, non_modifiable_changeset}
      end
    else
      error -> error
    end
  end

  defp do_update_rule(changeset) do
    with {:ok, rule} <- Repo.update(changeset) do
      rule =
        rule
        |> Repo.preload(:rule_type)
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

  def get_rule_detail!(id) do
    id
    |> get_rule!()
    |> Repo.preload(:rule_type)
    |> load_relation_detail_from_cache()
  end

  defp load_relation_detail_from_cache(%Rule{business_concept_id: nil} = rule), do: rule

  defp load_relation_detail_from_cache(%Rule{rule_type: rule_type} = rule) do
    list_filters =
      rule_type
      |> Map.get(:params, %{})
      |> Map.get("system_params", [])
      |> retrieve_params_to_filter()

    case list_filters do
      [] -> rule
      list_filters -> rule |> retrieve_cache_information(list_filters)
    end
  end

  defp retrieve_params_to_filter([]), do: []

  defp retrieve_params_to_filter(system_params) do
    filters_in_system_params =
      system_params
      |> Enum.map(&Map.get(&1, "name"))

    ["system" | filters_in_system_params] |> Enum.uniq()
  end

  defp retrieve_cache_information(%Rule{business_concept_id: bc_id} = rule, list_filters) do
    {:ok, linked_resources} = LinkCache.list("business_concept", bc_id, "data_field")

    system_values =
      list_filters
      |> Enum.map(&append_values(&1, linked_resources))
      |> Enum.reject(fn {_, values} -> Enum.empty?(values) end)
      |> Enum.into(%{})

    rule |> Map.put(:system_values, system_values)
  end

  defp append_values("system" = key, list_resources) do
    values =
      list_resources
      |> Enum.map(fn %{system: %{name: name}} ->
        build_resource_map(name, key, name)
      end)
      |> Enum.uniq_by(fn %{"name" => name} -> name end)

    {key, values}
  end

  defp append_values("group" = key, list_resources) do
    values =
      list_resources
      |> Enum.map(fn %{system: %{name: system}, group: group} ->
        build_resource_map(group, key, group, system)
      end)
      |> Enum.uniq_by(fn %{"resource_id" => resource_id} -> resource_id end)

    {key, values}
  end

  defp append_values("table" = key, list_resources) do
    values =
      list_resources
      |> Enum.map(fn %{group: group, structure_id: structure_id, path: path} ->
        [_field | [name | _]] = Enum.reverse(path)
        build_resource_map(name, key, structure_id, group)
      end)
      |> Enum.uniq_by(fn %{"resource_id" => resource_id} -> resource_id end)

    {key, values}
  end

  defp append_values("column" = key, list_resources) do
    values =
      list_resources
      |> Enum.map(fn %{id: id, name: name, parent_id: parent_id} ->
        build_resource_map(name, key, id, parent_id)
      end)
      |> Enum.uniq_by(fn %{"resource_id" => resource_id} -> resource_id end)

    {key, values}
  end

  defp append_values(key, _), do: {key, []}

  defp build_resource_map(name, resource_type, resource_id) do
    Map.new()
    |> Map.put("name", name)
    |> Map.put("resource_type", resource_type)
    |> Map.put("resource_id", resource_id)
  end

  defp build_resource_map(name, resource_type, resource_id, parent_key) do
    name
    |> build_resource_map(resource_type, resource_id)
    |> Map.put("parent_key", parent_key)
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

      iex> list_rule_implementations()
      [%RuleImplementation{}, ...]

  """
  def list_rule_implementations(params \\ %{})

  def list_rule_implementations(params) do
    dynamic = filter(params, RuleImplementation.__schema__(:fields))
    rule_params = Map.get(params, :rule) || Map.get(params, "rule", %{})
    rule_fields = Rule.__schema__(:fields)

    dynamic =
      Enum.reduce(Map.keys(rule_params), dynamic, fn key, acc ->
        key_as_atom = if is_binary(key), do: String.to_atom(key), else: key

        case {Enum.member?(rule_fields, key_as_atom), is_map(Map.get(rule_params, key))} do
          {true, true} ->
            json_query = Map.get(rule_params, key)

            dynamic(
              [_, p],
              fragment("(?) @> ?::jsonb", field(p, ^key_as_atom), ^json_query) and ^acc
            )

          {true, false} ->
            dynamic([_, p], field(p, ^key_as_atom) == ^rule_params[key] and ^acc)

          {false, _} ->
            acc
        end
      end)

    query =
      from(
        ri in RuleImplementation,
        inner_join: r in Rule,
        on: ri.rule_id == r.id,
        where: ^dynamic,
        where: is_nil(r.deleted_at),
        where: is_nil(ri.deleted_at)
      )

    query |> Repo.all()
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
      |> Repo.preload(rule: :rule_type)

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
        input = Changeset.get_change(changeset, :system_params)
        rule_type = get_rule_type_or_nil(rule)
        types = get_system_params_or_nil(rule_type)
        types_changeset = rule_type_changeset(types, input)

        case types_changeset.valid? do
          true -> insert_rule_implementation(changeset)
          false -> {:error, types_changeset}
        end

      false ->
        {:error, changeset}
    end
  end

  def get_rule_implementation_system_params_info(%RuleImplementation{} = rule_implementation) do
    system_params = Map.get(rule_implementation, :system_params, %{})

    new_system_params =
      rule_implementation
      |> get_rule_implementation_structure_system_params()
      |> Enum.into(system_params, fn {key, value} ->
        structure_id = Map.get(value, "id")
        structure = read_structure_from_cache(structure_id, 0)
        param =
          Map.new
          |> Map.put(:id, structure_id)
          |> Map.put(:external_id, Map.get(structure, :external_id))
          |> Map.put(:name, Map.get(structure, :name, Map.get(value, "name", "")))
          |> Map.put(:path, Map.get(structure, :path, []))
          |> Map.put(:system, Map.get(structure, :system))
          |> Map.put(:type, Map.get(structure, :type))
        {key, param}
      end)

    Map.put(rule_implementation, :system_params, new_system_params)
  end

  defp read_structure_from_cache(structure_id, 3) do
    %{id: structure_id}
  end

  defp read_structure_from_cache(structure_id, count) do
    {:ok, structure} = StructureCache.get(structure_id)

    case structure do
      nil -> read_structure_from_cache(structure_id, count + 1)
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

  def get_rule_implementation_structure_system_params(%RuleImplementation{} = rule_implementation) do
    type_params_names = get_structure_rule_type_params(rule_implementation)

    case type_params_names do
      [] ->
        []

      _ ->
        rule_implementation
        |> Map.get(:system_params, [])
        |> Enum.filter(fn {key, value} ->
          key in type_params_names and Map.has_key?(value, "id")
        end)
    end
  end

  defp add_rule_implementation_structure_links(%RuleImplementation{} = rule_implementation) do
    rule_implementation
    |> get_rule_implementation_structure_system_params()
    |> Enum.map(fn {_key, value} ->
      Map.get(value, "id")
    end)
    |> Enum.uniq()
    |> Enum.map(&add_rule_implementation_structure_link/1)
  end

  defp get_structure_rule_type_params(%RuleImplementation{
         rule: %{rule_type: %{params: %{"system_params" => rule_type_system_params}}}
       }) do
    rule_type_system_params
    |> Enum.filter(fn param -> Map.get(param, "type") == "structure" end)
    |> Enum.map(fn param -> Map.get(param, "name") end)
  end

  defp get_structure_rule_type_params(_rule_implementation) do
    []
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
        input = Map.get(attrs, :system_params) || Map.get(attrs, "system_params", %{})
        rule_type = Repo.preload(rule_implementation, [:rule, rule: :rule_type]).rule.rule_type
        types = get_system_params_or_nil(rule_type)
        type_changeset = rule_type_changeset(types, input)

        case type_changeset.valid? do
          true -> update_rule_implementation(changeset)
          false -> {:error, type_changeset}
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

      iex> delete_rule_implementation(rule_implementation)
      {:ok, %RuleImplementation{}}

      iex> delete_rule_implementation(rule_implementation)
      {:error, %Ecto.Changeset{}}

  """
  def delete_rule_implementation(%RuleImplementation{} = rule_implementation) do
    Repo.delete(rule_implementation)
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

  alias TdDq.Rules.RuleType

  @doc """
  Returns the list of rule_type.

  ## Examples

      iex> list_rule_types()
      [%RuleType{}, ...]

  """
  def list_rule_types do
    Repo.all(RuleType)
  end

  @doc """
  Gets a single rule_type.

  Raises `Ecto.NoResultsError` if the Rule types does not exist.

  ## Examples

      iex> get_rule_type!(123)
      %RuleType{}

      iex> get_rule_type!(456)
      ** (Ecto.NoResultsError)

  """
  def get_rule_type!(id), do: Repo.get!(RuleType, id)

  @doc """
  Gets a single rule_type.

  ## Examples

      iex> get_rule_type(123)
      %RuleType{}

      iex> get_rule_type(456)
      ** nil

  """
  def get_rule_type(id), do: Repo.get(RuleType, id)

  def get_rule_type_by_name(name) do
    Repo.get_by(RuleType, name: name)
  end

  @doc """
  Creates a rule_type.

  ## Examples

      iex> create_rule_type(%{field: value})
      {:ok, %RuleType{}}

      iex> create_rule_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_rule_type(attrs \\ %{}) do
    %RuleType{}
    |> RuleType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a rule_type.

  ## Examples

      iex> update_rule_type(rule_type, %{field: new_value})
      {:ok, %RuleType{}}

      iex> update_rule_type(rule_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_rule_type(%RuleType{} = rule_type, attrs) do
    rule_type
    |> RuleType.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a RuleType.

  ## Examples

      iex> delete_rule_type(rule_type)
      {:ok, %RuleType{}}

      iex> delete_rule_type(rule_type)
      {:error, %Ecto.Changeset{}}

  """
  def delete_rule_type(%RuleType{} = rule_type) do
    Repo.delete(rule_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking rule_type changes.

  ## Examples

      iex> change_rule_type(rule_type)
      %Ecto.Changeset{source: %RuleType{}}

  """
  def change_rule_type(%RuleType{} = rule_type) do
    RuleType.changeset(rule_type, %{})
  end

  def get_rule_or_nil(id) when is_nil(id) or id == "", do: nil
  def get_rule_or_nil(id), do: get_rule(id)

  def get_rule_type_or_nil(id) when is_nil(id) or is_binary(id), do: nil
  def get_rule_type_or_nil(id) when is_integer(id), do: get_rule_type(id)
  def get_rule_type_or_nil(%Rule{} = rule), do: Repo.preload(rule, :rule_type).rule_type

  defp get_system_params_or_nil(nil), do: nil

  defp get_system_params_or_nil(%RuleType{} = rule_type) do
    rule_type.params["system_params"]
    |> case do
      nil -> nil
      params -> params |> Enum.filter(fn param -> Map.get(param, "hidden") in [nil, false] end)
    end
  end

  defp get_type_params_or_nil(nil), do: nil

  defp get_type_params_or_nil(%RuleType{} = rule_type) do
    rule_type.params["type_params"]
  end

  defp filter(params, fields) do
    dynamic = true

    Enum.reduce(Map.keys(params), dynamic, fn key, acc ->
      key_as_atom = if is_binary(key), do: String.to_atom(key), else: key

      case Enum.member?(fields, key_as_atom) and !is_map(Map.get(params, key)) do
        true -> dynamic([p], field(p, ^key_as_atom) == ^params[key] and ^acc)
        false -> acc
      end
    end)
  end

  defp rule_type_changeset(nil, _input), do: Changeset.cast({%{}, %{}}, %{}, [])

  defp rule_type_changeset(types, input) do
    fields =
      types
      |> Enum.map(&{String.to_atom(&1["name"]), to_schema_type(&1["type"])})
      |> Map.new()

    {input, fields}
    |> Changeset.cast(input, Map.keys(fields))
    |> Changeset.validate_required(Map.keys(fields))
  end

  defp validate_non_modifiable_fields(changeset, %{rule_type_id: _}),
    do: add_non_modifiable_error(changeset, :rule_type_id, "non.modifiable.field")

  defp validate_non_modifiable_fields(changeset, %{"rule_type_id" => _}),
    do: add_non_modifiable_error(changeset, :rule_type_id, "non.modifiable.field")

  defp validate_non_modifiable_fields(changeset, _attrs),
    do: changeset

  defp add_non_modifiable_error(changeset, field, message),
    do: Changeset.add_error(changeset, field, message)

  defp add_rule_type_params_validations(changeset, _, nil), do: changeset

  defp add_rule_type_params_validations(changeset, %{name: "integer_values_range"}, _) do
    case changeset.valid? do
      true ->
        min_value = Changeset.get_field(changeset, :min_value)
        max_value = Changeset.get_field(changeset, :max_value)

        case min_value <= max_value do
          true ->
            changeset

          false ->
            Changeset.add_error(changeset, :max_value, "must.be.greater.than.or.equal.to.minimum")
        end

      false ->
        changeset
    end
  end

  defp add_rule_type_params_validations(changeset, %{name: "dates_range"}, _) do
    case changeset.valid? do
      true ->
        with {:ok, min_date} <-
               parse_date(Changeset.get_field(changeset, :min_date), :error_min_date),
             {:ok, max_date} <-
               parse_date(Changeset.get_field(changeset, :max_date), :error_max_date),
             {:ok} <- validate_date_range(min_date, max_date) do
          changeset
        else
          {:error, :error_min_date} ->
            Changeset.add_error(changeset, :min_date, "cast.date")

          {:error, :error_max_date} ->
            Changeset.add_error(changeset, :max_date, "cast.date")

          {:error, :invalid_range} ->
            Changeset.add_error(changeset, :max_date, "must.be.greater.than.or.equal.to.min_date")
        end

      false ->
        changeset
    end
  end

  defp add_rule_type_params_validations(changeset, _, types) do
    add_type_params_validations(changeset, types)
  end

  defp add_type_params_validations(changeset, [head | tail]) do
    changeset
    |> add_type_params_validations(head)
    |> add_type_params_validations(tail)
  end

  defp add_type_params_validations(changeset, []), do: changeset

  defp add_type_params_validations(changeset, %{"name" => name, "type" => "date"}) do
    field = String.to_atom(name)

    case Date.from_iso8601(Changeset.get_field(changeset, field)) do
      {:ok, _} -> changeset
      _ -> Changeset.add_error(changeset, field, "cast.date")
    end
  end

  defp add_type_params_validations(changeset, _), do: changeset

  defp parse_date(value, error_code) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, date}
      _ -> {:error, error_code}
    end
  end

  defp validate_date_range(from, to) do
    case Date.compare(from, to) do
      :lt -> {:ok}
      :eq -> {:ok}
      :gt -> {:error, :invalid_range}
    end
  end

  defp to_schema_type("integer"), do: :integer
  defp to_schema_type("string"), do: :string
  defp to_schema_type("list"), do: {:array, :string}
  defp to_schema_type("date"), do: :string
  defp to_schema_type("structure"), do: :map
  defp to_schema_type("float"), do: :float
  defp to_schema_type("whole_number"), do: :integer
  defp to_schema_type("boolean"), do: :boolean

  def check_available_implementation_key(%{"implementation_key" => ""}),
    do: {:implementation_key_available}

  def check_available_implementation_key(%{"implementation_key" => implementation_key}) do
    count =
      RuleImplementation
      |> where([ri], ri.implementation_key == ^implementation_key and is_nil(ri.deleted_at))
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
    Repo.all(RuleResult)
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
        (r.result_type == ^Rule.result_type().errors_number and rr.result > r.goal)
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
    |> order_by(desc: :date)
    |> limit(1)
    |> Repo.one()
  end
end
