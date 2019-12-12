defmodule TdDq.Rules.RuleImplementation do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias TdDq.Rules.Rule
  alias TdDq.Rules.RuleImplementation
  alias TdDq.Rules.RuleImplementation.ConditionRow
  alias TdDq.Rules.RuleImplementation.DatasetRow

  schema "rule_implementations" do
    field(:implementation_key, :string)

    embeds_many(:dataset, DatasetRow, on_replace: :delete)
    embeds_many(:population, ConditionRow, on_replace: :delete)
    embeds_many(:validations, ConditionRow, on_replace: :delete)

    belongs_to(:rule, Rule)

    field(:deleted_at, :utc_datetime)
    timestamps()
  end

  @doc false
  def changeset(%RuleImplementation{} = rule_implementation, attrs) do
    rule_implementation
    |> cast(attrs, [
      :deleted_at,
      :rule_id,
      :implementation_key
    ])
    |> cast_embed(:dataset, with: &DatasetRow.changeset/2, required: true)
    |> cast_embed(:population, with: &ConditionRow.changeset/2, required: false)
    |> cast_embed(:validations, with: &ConditionRow.changeset/2, required: true)
    |> validate_required([:rule_id, :dataset, :validations])
    |> validate_length(:implementation_key, max: 255)
  end
end

defmodule TdDq.Rules.RuleImplementation.DatasetRow do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias TdDq.Rules.RuleImplementation.Structure

  @primary_key false
  embedded_schema do
    embeds_one(:structure, Structure, on_replace: :delete)
    embeds_one(:right, Structure, on_replace: :delete)
    embeds_one(:left, Structure, on_replace: :delete)
    field(:join_type, :string)
  end

  def changeset(%__MODULE__{} = lead, params \\ %{}) do
    left_required = Enum.find(get_validate_required(params), fn elem -> elem == :left end)
    right_required = Enum.find(get_validate_required(params), fn elem -> elem == :right end)

    lead
    |> cast(params, [:join_type])
    |> cast_embed(:structure, with: &Structure.changeset/2, required: true)
    |> cast_embed(:left, with: &Structure.changeset/2, required: left_required)
    |> cast_embed(:right, with: &Structure.changeset/2, required: right_required)
  end

  defp get_validate_required(params) do
    case Map.get(params, :join_type, Map.get(params, "join_type")) do
      nil -> []
      _join_type -> [:left, :right]
    end
  end
end

defmodule TdDq.Rules.RuleImplementation.Structure do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:id, :integer)
  end

  def changeset(%__MODULE__{} = lead, params \\ %{}) do
    lead
    |> cast(params, __schema__(:fields))
    |> validate_required([:id])
  end
end

defmodule TdDq.Rules.RuleImplementation.ConditionRow do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias TdDq.Rules.RuleImplementation.Operator
  alias TdDq.Rules.RuleImplementation.Structure

  @primary_key false
  embedded_schema do
    embeds_one(:structure, Structure, on_replace: :delete)
    embeds_one(:operator, Operator, on_replace: :delete)
    field(:value, {:array, :map})
  end

  def changeset(%__MODULE__{} = lead, params \\ %{}) do
    lead
    |> cast(params, [:value])
    |> cast_embed(:structure, with: &Structure.changeset/2, required: true)
    |> cast_embed(:operator, with: &Operator.changeset/2, required: true)
    |> validate_required([:value])
    |> validate_value(params)
  end

  defp validate_value(%{valid: false} = changeset, _params) do
    changeset
  end

  defp validate_value(changeset, params) do
    value = get_change(changeset, :value)

    case valid_value?(value, changeset, params) do
      {:ok, changeset} -> valid_range?(value, changeset, params)
      {:invalid_value, changeset} -> changeset
    end
  end

  defp valid_range?([%{"raw" => value_left}, %{"raw" => value_right}], changeset, %{
         "operator" => %{
           "name" => "between",
           "value_type" => type
         }
       }) do
    case type do
      "date" ->
        valid_range_dates(value_left, value_right, changeset, :utc_date)

      "timestamp" ->
        valid_range_dates(value_left, value_right, changeset, :utc)

      "number" ->
        valid_range_number(value_left, value_right, changeset)

      _other ->
        add_error(changeset, :value, "invalid.operator.type", validation: :invalid_operator_type)
    end
  end

  # length_between
  defp valid_range?([%{"raw" => value_left}, %{"raw" => value_right}], changeset, %{
         "operator" => %{
           "name" => "length_between",
           "value_type" => "number"
         }
       }) do
    case value_left <= value_right do
      true ->
        changeset

      _ ->
        add_error(changeset, :value, "invalid.range",
          validation: :invalid_length_between_value_type
        )
    end
  end

  defp valid_range?([%{"raw" => _value_left}, %{"raw" => _value_right}], changeset, %{
         "operator" => %{
           "name" => "length_between",
           "value_type" => _other_type
         }
       }) do
    add_error(changeset, :value, "invalid.value.type",
      validation: :legth_between_left_value_must_be_le_than_right
    )
  end

  defp valid_range?(_value, changeset, _operator) do
    changeset
  end

  defp valid_range_dates(value_left, value_right, changeset, date_format) do
    with {:ok, date1, _} <- TdDq.DateParser.parse(value_left, [date_format]),
         {:ok, date2, _} <- TdDq.DateParser.parse(value_right, [date_format]) do
      case DateTime.compare(date1, date2) in [:lt, :eq] do
        true ->
          changeset

        _ ->
          add_error(changeset, :value, "invalid.range.dates",
            validation: :left_value_must_be_le_than_right
          )
      end
    else
      _ ->
        add_error(changeset, :value, "invalid.range.dates", validation: :invalid_date_format)
    end
  end

  defp valid_range_number(value_left, value_right, changeset) do
    case value_left <= value_right do
      true ->
        changeset

      _ ->
        add_error(changeset, :value, "invalid.range.dates",
          validation: :left_value_must_be_le_than_right
        )
    end
  end

  defp valid_value?(value, changeset, params) do
    case Enum.all?(value, &valid_attribute(&1, params)) do
      true ->
        {:ok, changeset}

      false ->
        {:invalid_value, add_error(changeset, :value, "invalid_attribute", validation: :invalid)}
    end
  end

  defp valid_attribute(%{"id" => id}, _params) do
    is_integer(id)
  end

  defp valid_attribute(%{"raw" => raw}, %{"operator" => %{"value_type" => value_type}}) do
    is_valid_type_value(value_type, raw)
  end

  defp valid_attribute(_, _), do: false

  defp is_valid_type_value("number", value) do
    is_integer(value) || is_float(value)
  end

  defp is_valid_type_value("string", value) do
    is_binary(value)
  end

  defp is_valid_type_value("date", value) do
    is_binary(value) && is_date(value)
  end

  defp is_valid_type_value("timestamp", value) do
    is_binary(value) && is_timestamp(value)
  end

  defp is_valid_type_value("string_list", value) do
    is_list(value)
  end

  defp is_valid_type_value(_other_type, _value) do
    false
  end

  defp is_date(date) do
    case TdDq.DateParser.parse(date, [:utc_date]) do
      {:ok, _date, _} -> true
      _ -> false
    end
  end

  defp is_timestamp(date) do
    case TdDq.DateParser.parse(date, [:utc]) do
      {:ok, _date, _} -> true
      _ -> false
    end
  end
end

defmodule TdDq.Rules.RuleImplementation.Operator do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:name, :string)
    field(:value_type, :string)
  end

  def changeset(%__MODULE__{} = lead, params \\ %{}) do
    lead
    |> cast(params, [:name, :value_type])
    |> validate_required([:name])
  end
end
