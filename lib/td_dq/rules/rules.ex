defmodule TdDq.Rules do
  @moduledoc """
  The Rules context.
  """

  import Ecto.Query, warn: false
  alias Ecto.Changeset
  alias TdDq.Repo

  alias TdDq.Rules.Rule
  alias TdDq.Rules.RuleImplementation
  alias TdDq.Rules.RuleResult
  alias TdDq.Rules.RuleType

  @datetime_format "%Y-%m-%d %H:%M:%S"
  @date_format "%Y-%m-%d"

  @doc """
  Returns the list of rules.

  ## Examples

      iex> list_rules()
      [%Rule{}, ...]

  """
  def list_rules(params \\ %{})
  def list_rules(params) do
    fields = Rule.__schema__(:fields)
    dynamic = filter(params, fields)
    query = from(
      p in Rule,
      where: ^dynamic
    )

    query
      |> Repo.all()
      |> Repo.preload(:rule_type)
  end

  @doc """
  Gets a single rule.

  Raises `Ecto.NoResultsError` if the Quality control does not exist.

  ## Examples

      iex> get_rule!(123)
      %Rule{}

      iex> get_rule!(456)
      ** (Ecto.NoResultsError)

  """
  def get_rule!(id), do: Repo.get!(Rule, id)

  @doc """
  Gets a single rule.

  ## Examples

      iex> get_rule(123)
      %Rule{}

      iex> get_rule(456)
      ** nil

  """
  def get_rule(id), do: Repo.get(Rule, id)

  def parse_rule_params(params, nil), do: params
  def parse_rule_params(params, %RuleType{} = rule_type) do
    types = get_type_params_or_nil(rule_type)
    type_params = Map.get(params, "type_params", %{})
    Map.put(params, "type_params", parse_params(type_params, types))
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
    changeset = Rule.changeset(%Rule{}, attrs)
    case changeset.valid? do
      true ->
        input = Changeset.get_change(changeset, :type_params)
        types = get_type_params_or_nil(rule_type)
        type_changeset = types
        |> rule_type_changeset(input)
        |> add_rule_type_params_validations(rule_type, types)
        case type_changeset.valid? do
          true ->  changeset |> Repo.insert()
          false -> {:error, type_changeset}
        end
      false -> {:error, changeset}
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
    changeset = Rule.changeset(rule, attrs)
    case changeset.valid? do
      true ->
        input     = Map.get(attrs, :type_params) || Map.get(attrs, "type_params", %{})
        rule_type = Repo.preload(rule, :rule_type).rule_type
        types     = get_type_params_or_nil(rule_type)
        type_changeset = types
        |> rule_type_changeset(input)
        |> add_rule_type_params_validations(rule_type, types)
        case type_changeset.valid? do
          true ->  changeset |> Repo.update()
          false -> {:error, type_changeset}
        end
      false -> {:error, changeset}
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
  def delete_rule(%Rule{} = rule) do
    Repo.delete(rule)
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

  def list_rule_results do
    Repo.all(RuleResult)
  end

  def list_concept_rules(params) do
    fields = Rule.__schema__(:fields)
    dynamic = filter(params, fields)

    query = from(
      p in Rule,
      where: ^dynamic,
      order_by: [desc: :business_concept_id]
    )

    query |> Repo.all()
  end

  def get_last_rule_result(rule_implementation_id) do
    RuleResult
    |> where([r], r.rule_implementation_id == ^rule_implementation_id)
    |> order_by(desc: :date)
    |> limit(1)
    |> Repo.one()
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
    dynamic = Enum.reduce(Map.keys(rule_params), dynamic, fn key, acc ->
      key_as_atom = if is_binary(key), do: String.to_atom(key), else: key
      case Enum.member?(rule_fields, key_as_atom) do
        true -> dynamic([_, p], field(p, ^key_as_atom) == ^rule_params[key] and ^acc)
        false -> acc
      end
    end)

    query = from(
      ri in RuleImplementation,
      inner_join: r in Rule,
      on: ri.rule_id == r.id,
      where: ^dynamic
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
  def get_rule_implementation!(id), do: Repo.get!(RuleImplementation, id)

  @doc """
  Gets a single rule_implementation.

  Returns nil if the Rule does not exist.

  ## Examples

      iex> get_rule_implementation!(123)
      %RuleImplementation{}

      iex> get_rule_implementation!(456)
      nil

  """
  def get_rule_implementation(id), do: Repo.get(RuleImplementation, id)

  def parse_rule_implementation_params(params, nil), do: params
  def parse_rule_implementation_params(params, %RuleType{} = rule_type) do
    types = get_system_params_or_nil(rule_type)
    system_params = Map.get(params, "system_params", %{})
    Map.put(params, "system_params", parse_params(system_params, types))
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
    changeset = RuleImplementation.changeset(%RuleImplementation{}, attrs)
    case changeset.valid? do
      true ->
        input = Changeset.get_change(changeset, :system_params)
        rule_type = get_rule_type_or_nil(rule)
        types = get_system_params_or_nil(rule_type)
        types_changeset = rule_type_changeset(types, input)
        case types_changeset.valid? do
          true ->  changeset |> Repo.insert()
          false -> {:error, types_changeset}
        end
      false -> {:error, changeset}
    end
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
        rule_type =
          Repo.preload(rule_implementation, [:rule, rule: :rule_type]).rule.rule_type
        types = get_system_params_or_nil(rule_type)
        type_changeset = rule_type_changeset(types, input)
        case type_changeset.valid? do
          true ->  changeset |> Repo.update()
          false -> {:error, type_changeset}
        end
      false -> {:error, changeset}
    end
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
  def get_rule_type_or_nil(id) when is_integer(id) , do: get_rule_type(id)
  def get_rule_type_or_nil(%Rule{} = rule), do: Repo.preload(rule, :rule_type).rule_type

  defp parse_params(params, types) do
    types = case types do
      nil -> []
      types -> types
    end
    Enum.reduce(types, params, &parse_param(&2, &1))
  end

  defp parse_param(params, %{"name" => name, "type" => "integer"}) do
    case Map.get(params, name) do
      value when is_binary(value) ->
        Map.put(params, name, String.to_integer(value))
      _ -> params
    end
  end
  defp parse_param(params, %{"name" => name, "type" => "string"}) do
    case Map.get(params, name) do
      value when not is_nil(value) ->
        Map.put(params, name, to_string(value))
      _ -> params
    end
  end
  defp parse_param(params, %{"name" => name, "type" => "list"}) do
    case Map.get(params, name) do
      value when is_binary(value) ->
        Map.put(params, name, String.split(value, ","))
      _ -> params
    end
  end
  defp parse_param(params, %{"name" => name, "type" => "date"}) do
    case Map.get(params, name) do
      value when is_binary(value) ->
        parsed_value = parse_date(value)
        case parsed_value do
          nil ->
            #params
            Map.put(params, name, nil) # trigger required
          _datetime ->
            #Map.put(params, name, DateTime.to_iso8601(datetime))
            params
        end
      _ -> params
    end
  end
  defp parse_param(params, _), do: params

  defp parse_date(value) do
    binary_to_date(value) || binary_to_datetime(value)
  end

  defp binary_to_date(value) do
    case Timex.parse(value, @date_format, :strftime) do
      {:ok, date} -> Timex.to_datetime(date)
      _ -> nil
    end
  end

  defp binary_to_datetime(value) do
    case Timex.parse(value, @datetime_format, :strftime) do
      {:ok, date} -> Timex.to_datetime(date)
      _ -> nil
    end
  end

  defp get_system_params_or_nil(nil), do: nil
  defp get_system_params_or_nil(%RuleType{} = rule_type) do
    rule_type.params["system_params"]
  end

  defp get_type_params_or_nil(nil), do: nil
  defp get_type_params_or_nil(%RuleType{} = rule_type) do
    rule_type.params["type_params"]
  end

  defp filter(params, fields) do
    dynamic = true
    Enum.reduce(Map.keys(params), dynamic, fn key, acc ->
      key_as_atom = if is_binary(key), do: String.to_atom(key), else: key
      case Enum.member?(fields, key_as_atom) do
        true -> dynamic([p], field(p, ^key_as_atom) == ^params[key] and ^acc)
        false -> acc
      end
    end)
  end

  defp rule_type_changeset(nil, _input), do: Changeset.cast({%{}, %{}}, %{}, [])
  defp rule_type_changeset(types, input) do
    fields = types
    |> Enum.map(&({String.to_atom(&1["name"]), to_schema_type(&1["type"])}))
    |> Map.new

    {input, fields}
    |> Changeset.cast(input, Map.keys(fields))
    |> Changeset.validate_required(Map.keys(fields))
  end

  defp add_rule_type_params_validations(changeset, _, nil), do: changeset
  defp add_rule_type_params_validations(changeset, %{name: "integer_values_range"}, _) do
    case changeset.valid? do
      true ->
        min_value = Changeset.get_field(changeset, :min_value)
        max_value = Changeset.get_field(changeset, :max_value)
        case min_value <= max_value do
          true -> changeset
          false -> Changeset.add_error(changeset, :max_value, "must.be.greater.than.or.equal.to.minimum")
        end
      false -> changeset
    end
  end
  defp add_rule_type_params_validations(changeset, %{name: "dates_range"}, _) do
    # case changeset.valid? do
    #   true ->
    #     min_date = binary_to_date(Changeset.get_field(changeset, :min_date))
    #     max_date = Changeset.get_field(changeset, :max_date)
    #
    #     # DateTime.from_iso8601(mix_date, calendar)
    #     # DateTime.from_iso8601(max_date, calendar)
    #
    #     case DateTime.compare(min_date, max_date) do
    #       :lt -> changeset
    #       :eq -> changeset
    #       :gt -> Changeset.add_error(changeset, :max_date, "must.be.greater.than.or.equal.to.minimum")
    #     end
    #   false -> changeset
    # end
    changeset
  end
  defp add_rule_type_params_validations(changeset, _, _), do: changeset

  defp to_schema_type("integer"), do: :integer
  defp to_schema_type("string"),  do: :string
  defp to_schema_type("list"),    do: {:array, :string}
  defp to_schema_type("date"),    do: :string

end
