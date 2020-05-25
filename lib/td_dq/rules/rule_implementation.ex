defmodule TdDq.Rules.RuleImplementation do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias TdDq.Rules.Rule
  alias TdDq.Rules.RuleImplementation
  alias TdDq.Rules.RuleImplementation.ConditionRow
  alias TdDq.Rules.RuleImplementation.DatasetRow
  alias TdDq.Rules.RuleImplementation.RawContent

  schema "rule_implementations" do
    field(:implementation_key, :string)
    field(:implementation_type, :string, default: "default")

    embeds_many(:dataset, DatasetRow, on_replace: :delete)
    embeds_many(:population, ConditionRow, on_replace: :delete)
    embeds_many(:validations, ConditionRow, on_replace: :delete)

    embeds_one(:raw_content, RawContent, on_replace: :delete)

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
      :implementation_key,
      :implementation_type
    ])
    |> custom_changeset(rule_implementation)
    |> validate_length(:implementation_key, max: 255)
    |> validate_inclusion(:implementation_type, ["default", "raw"])
  end

  defp custom_changeset(
         %Ecto.Changeset{changes: %{implementation_type: "raw"}} = changeset,
         _rule_implementation
       ) do
    raw_changeset(changeset)
  end

  defp custom_changeset(%Ecto.Changeset{} = changeset, %RuleImplementation{
         implementation_type: "raw"
       }) do
    raw_changeset(changeset)
  end

  defp custom_changeset(
         %Ecto.Changeset{changes: %{implementation_type: _type}} = changeset,
         _rule_implementation
       ) do
    default_changeset(changeset)
  end

  defp custom_changeset(%Ecto.Changeset{} = changeset, %RuleImplementation{
         implementation_type: _type
       }) do
    default_changeset(changeset)
  end

  defp raw_changeset(changeset) do
    changeset
    |> cast_embed(:raw_content, with: &RawContent.changeset/2, required: true)
    |> validate_required([:rule_id, :raw_content])
  end

  def default_changeset(changeset) do
    changeset
    |> cast_embed(:dataset, with: &DatasetRow.changeset/2, required: true)
    |> cast_embed(:population, with: &ConditionRow.changeset/2, required: false)
    |> cast_embed(:validations, with: &ConditionRow.changeset/2, required: true)
    |> validate_required([:rule_id, :dataset, :validations])
  end
end

defmodule TdDq.Rules.RuleImplementation.RawContent do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:dataset, :string)
    field(:population, :string)
    field(:validations, :string)
    field(:system, :integer)
    field(:structure_alias, :string)
  end

  def changeset(%__MODULE__{} = lead, params \\ %{}) do
    lead
    |> cast(params, [:dataset, :population, :validations, :system, :structure_alias])
    |> valid_content?([:dataset, :population, :validations])
    |> validate_required([:dataset, :validations])
    |> validate_required_inclusion([:system, :structure_alias])
  end

  def validate_required_inclusion(changeset, fields) do
    if Enum.any?(fields, &present?(changeset, &1)) do
      changeset
    else
      add_error(changeset, hd(fields), "One of these fields must be present: [system, structure_alias]")
    end
  end

  def present?(changeset, field) do
    value = get_field(changeset, field)
    value != nil && value != "" && value != %{}
  end

  defp valid_content?(changeset, fields) do
    Enum.reduce(fields, changeset, fn field, changeset ->
      field_value = get_change(changeset, field)

      case has_invalid_content(field_value) do
        true ->
          add_error(changeset, field, "invalid.#{field}",
            validation: String.to_atom("invalid_content")
          )

        _ ->
          changeset
      end
    end)
  end

  def has_invalid_content(nil) do
    false
  end

  def has_invalid_content(text) do
    result =
      Regex.run(~r/(?i)(\b(DROP|DELETE|INSERT|UPDATE|CALL|EXEC|EXECUTE|ALTER)\b|;|--|#)/, text)

    result != nil && length(result) > 0
  end
end

defmodule TdDq.Rules.RuleImplementation.DatasetRow do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias TdDq.Rules.RuleImplementation.JoinClause
  alias TdDq.Rules.RuleImplementation.Structure

  @primary_key false
  embedded_schema do
    embeds_one(:structure, Structure, on_replace: :delete)
    embeds_many(:clauses, JoinClause, on_replace: :delete)
    field(:join_type, :string)
  end

  def changeset(%__MODULE__{} = lead, params \\ %{}) do
    clauses_required = get_validate_required(params)

    lead
    |> cast(params, [:join_type])
    |> cast_embed(:structure, with: &Structure.changeset/2, required: true)
    |> cast_embed(:clauses, with: &JoinClause.changeset/2, required: clauses_required)
  end

  defp get_validate_required(params) do
    case Map.get(params, :join_type, Map.get(params, "join_type")) do
      nil -> false
      _join_type -> true
    end
  end
end

defmodule TdDq.Rules.RuleImplementation.JoinClause do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias TdDq.Rules.RuleImplementation.Structure

  @primary_key false
  embedded_schema do
    embeds_one(:right, Structure, on_replace: :delete)
    embeds_one(:left, Structure, on_replace: :delete)
  end

  def changeset(%__MODULE__{} = lead, params \\ %{}) do
    lead
    |> cast(params, [])
    |> cast_embed(:left, with: &Structure.changeset/2, required: true)
    |> cast_embed(:right, with: &Structure.changeset/2, required: true)
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
    field(:value_type_filter, :string)
  end

  def changeset(%__MODULE__{} = lead, params \\ %{}) do
    lead
    |> cast(params, [:name, :value_type, :value_type_filter])
    |> validate_required([:name])
  end
end
