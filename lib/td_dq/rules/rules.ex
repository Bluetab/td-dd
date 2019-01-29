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
    changeset = Rule.changeset(%Rule{}, attrs)

    case changeset.valid? do
      true ->
        input = Changeset.get_change(changeset, :type_params)
        types = get_type_params_or_nil(rule_type)

        type_changeset =
          types
          |> rule_type_changeset(input)
          |> add_rule_type_params_validations(rule_type, types)

        case type_changeset.valid? do
          true -> changeset |> Repo.insert()
          false -> {:error, type_changeset}
        end

      false ->
        {:error, changeset}
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
          true -> changeset |> Repo.update()
          false -> {:error, non_modifiable_changeset}
        end

      false ->
        {:error, changeset}
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
    rule
    |> Rule.delete_changeset()
    |> Repo.delete()
  end

  def soft_deletion(bcs_ids_to_delete, bcs_ids_to_avoid_deletion) do
    Rule
    |> where([r], not is_nil(r.business_concept_id))
    |> where([r], is_nil(r.deleted_at))
    |> where(
      [r],
      r.business_concept_id in ^bcs_ids_to_delete or
        r.business_concept_id not in ^bcs_ids_to_avoid_deletion
    )
    |> update(set: [deleted_at: ^DateTime.utc_now()])
    |> Repo.update_all([])
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

    query =
      from(
        p in Rule,
        where: ^dynamic,
        where: is_nil(p.deleted_at),
        order_by: [desc: :business_concept_id]
      )

    query |> Repo.all()
  end

  def get_last_rule_result(implementation_key) do
    RuleResult
    |> where([r], r.implementation_key == ^implementation_key)
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
        where: is_nil(r.deleted_at)
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

  def get_rule_implementation_by_key!(implementation_key) do
    RuleImplementation
    |> join(:inner, [ri], r in assoc(ri, :rule))
    |> where([_, r], is_nil(r.deleted_at))
    |> Repo.get_by!(implementation_key: implementation_key)
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
    changeset = RuleImplementation.changeset(%RuleImplementation{}, attrs)

    case changeset.valid? do
      true ->
        input = Changeset.get_change(changeset, :system_params)
        rule_type = get_rule_type_or_nil(rule)
        types = get_system_params_or_nil(rule_type)
        types_changeset = rule_type_changeset(types, input)

        case types_changeset.valid? do
          true -> changeset |> Repo.insert()
          false -> {:error, types_changeset}
        end

      false ->
        {:error, changeset}
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
        rule_type = Repo.preload(rule_implementation, [:rule, rule: :rule_type]).rule.rule_type
        types = get_system_params_or_nil(rule_type)
        type_changeset = rule_type_changeset(types, input)

        case type_changeset.valid? do
          true -> changeset |> Repo.update()
          false -> {:error, type_changeset}
        end

      false ->
        {:error, changeset}
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
  def get_rule_type_or_nil(id) when is_integer(id), do: get_rule_type(id)
  def get_rule_type_or_nil(%Rule{} = rule), do: Repo.preload(rule, :rule_type).rule_type

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

    case parse_date(Changeset.get_field(changeset, field), :error) do
      {:ok, _} -> changeset
      _ -> Changeset.add_error(changeset, field, "cast.date")
    end
  end

  defp add_type_params_validations(changeset, _), do: changeset

  defp parse_date(value, error_code) do
    case binary_to_date(value) do
      {:ok, date} ->
        {:ok, date}

      _ ->
        case binary_to_datetime(value) do
          {:ok, datetime} -> {:ok, datetime}
          _ -> {:error, error_code}
        end
    end
  end

  defp validate_date_range(from, to) do
    case DateTime.compare(from, to) do
      :lt -> {:ok}
      :eq -> {:ok}
      :gt -> {:error, :invalid_range}
    end
  end

  defp binary_to_date(value) do
    case Timex.parse(value, @date_format, :strftime) do
      {:ok, date} -> {:ok, Timex.to_datetime(date)}
      _ -> {:error}
    end
  end

  defp binary_to_datetime(value) do
    case Timex.parse(value, @datetime_format, :strftime) do
      {:ok, date} -> {:ok, Timex.to_datetime(date)}
      _ -> {:error}
    end
  end

  defp to_schema_type("integer"), do: :integer
  defp to_schema_type("string"), do: :string
  defp to_schema_type("list"), do: {:array, :string}
  defp to_schema_type("date"), do: :string

  def check_available_implementation_key(%{"implementation_key" => ""}),
    do: {:implementation_key_available}

  def check_available_implementation_key(%{"implementation_key" => implementation_key}) do
    count =
      RuleImplementation
      |> where([r], r.implementation_key == ^implementation_key)
      |> Repo.all()

    if Enum.empty?(count),
      do: {:implementation_key_available},
      else: {:implementation_key_not_available}
  end
end
