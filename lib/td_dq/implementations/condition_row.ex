defmodule TdDq.Implementations.ConditionRow do
  @moduledoc """
  Ecto Schema module for conditions in rule implementations.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDq.Implementations.Modifier
  alias TdDq.Implementations.Operator
  alias TdDq.Implementations.Structure

  @primary_key false
  embedded_schema do
    embeds_one(:structure, Structure, on_replace: :delete)
    embeds_one(:operator, Operator, on_replace: :delete)
    embeds_one(:modifier, Modifier, on_replace: :delete)
    embeds_many(:population, __MODULE__, on_replace: :delete)
    field(:value, {:array, :map})
    embeds_many(:value_modifier, Modifier, on_replace: :delete)
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = struct, %{} = params) do
    struct
    |> cast(params, [:value])
    |> cast_embed(:structure, with: &Structure.changeset/2, required: true)
    |> cast_embed(:modifier, with: &Modifier.changeset/2)
    |> cast_embed(:operator, with: &Operator.changeset/2, required: true)
    |> cast_embed(:population, with: &__MODULE__.changeset/2)
    |> cast_embed(:value_modifier, with: &Modifier.changeset/2)
    |> validate_required(:value)
    |> validate_value(params)
  end

  defp validate_value(%{valid?: false} = changeset, _params) do
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
    if value_left <= value_right do
      changeset
    else
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
      if DateTime.compare(date1, date2) in [:lt, :eq] do
        changeset
      else
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
    if value_left <= value_right do
      changeset
    else
      add_error(changeset, :value, "invalid.range.dates",
        validation: :left_value_must_be_le_than_right
      )
    end
  end

  defp valid_value?(value, changeset, params) do
    if Enum.all?(value, &valid_attribute(&1, params)) do
      {:ok, changeset}
    else
      {:invalid_value, add_error(changeset, :value, "invalid_attribute", validation: :invalid)}
    end
  end

  # One field
  defp valid_attribute(%{"id" => id}, _params) do
    is_integer(id)
  end

  # Several fields
  defp valid_attribute(%{"fields" => fields}, %{"operator" => %{"value_type" => value_type}}) do
    valid_type_value?(value_type, fields)
  end

  defp valid_attribute(%{"raw" => raw}, %{"operator" => %{"value_type" => value_type}}) do
    valid_type_value?(value_type, raw)
  end

  defp valid_attribute(
         %{"name" => name, "type" => "reference_dataset_field", "parent_index" => parent_index},
         _params
       ) do
    is_integer(parent_index) and is_binary(name) and String.trim(name) != ""
  end

  defp valid_attribute(
         %{
           "name" => header,
           "type" => "reference_dataset_field",
           "referenceDataset" => %{"id" => _ref_dataset_id, "name" => _ref_dataset_name}
         },
         _params
       ) do
    is_binary(header) and String.trim(header) != ""
  end

  defp valid_attribute(_, _), do: false

  defp valid_type_value?("number", value) do
    is_integer(value) || is_float(value)
  end

  defp valid_type_value?("string", value) do
    is_binary(value)
  end

  defp valid_type_value?("date", value) do
    is_binary(value) && date?(value)
  end

  defp valid_type_value?("timestamp", value) do
    is_binary(value) && timestamp?(value)
  end

  defp valid_type_value?("string_list", value) do
    is_list(value)
  end

  defp valid_type_value?("field_list", value) do
    is_list(value) and
      Enum.all?(value, fn
        %{"id" => id} -> is_integer(id)
        value -> valid_attribute(value, nil)
      end)
  end

  defp valid_type_value?(_other_type, _value) do
    false
  end

  defp date?(date) do
    case TdDq.DateParser.parse(date, [:utc_date]) do
      {:ok, _date, _} -> true
      _ -> false
    end
  end

  defp timestamp?(date) do
    case TdDq.DateParser.parse(date, [:utc]) do
      {:ok, _date, _} -> true
      _ -> false
    end
  end
end
