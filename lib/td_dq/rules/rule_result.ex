defmodule TdDq.Rules.RuleResult do
  @moduledoc """
  Ecto Schema module for Data Quality Rule Results.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias TdDfLib.Validation
  alias TdDq.DateParser
  alias TdDq.Executions.Execution
  alias TdDq.Implementations.Implementation
  alias TdDq.Remediations.Remediation
  alias TdDq.Rules.Rule
  alias TdDq.Rules.RuleResult

  @scale 2
  @valid_result_types Implementation.valid_result_types()
  @segments_validations [:result, :date, :result_type, :parent_id]
  @rule_resuls_validations [:implementation, :date, :result, :result_type]

  @typedoc "The result of a quality rule execution"
  @type t :: %__MODULE__{}

  schema "rule_results" do
    field(:date, :utc_datetime)
    field(:result, :decimal)
    field(:errors, :integer)
    field(:records, :integer)
    field(:params, :map, default: %{})
    field(:row_number, :integer, virtual: true)
    field(:result_type, :string)
    field(:details, :map, default: %{})

    belongs_to(:implementation, Implementation)
    belongs_to(:rule, Rule)
    belongs_to(:parent, RuleResult)

    has_many(:execution, Execution, foreign_key: :result_id)
    has_many(:rule_results, RuleResult, foreign_key: :parent_id)
    has_one(:remediation, Remediation)

    timestamps()
  end

  def changeset(:non_existing_nor_published, params) do
    %__MODULE__{}
    |> cast(params, [
      :row_number
    ])
    |> add_error(:implementation, "implementation does not exist or is not published")
  end

  def changeset(implementation, %{} = params) do
    changeset(%__MODULE__{}, implementation, params)
  end

  def changeset(%__MODULE__{} = struct, implementation, params) do
    struct
    |> cast(params, [
      :result,
      :errors,
      :records,
      :params,
      :row_number,
      :result_type,
      :details,
      :parent_id
    ])
    |> add_assoc(implementation)
    |> put_date()
    |> maybe_put_result()
    |> validate_inclusion(:result_type, @valid_result_types)
    |> update_change(:result, &Decimal.round(&1, @scale, :floor))
    |> add_validations()
    |> validate_number(:records, greater_than_or_equal_to: 0)
    |> validate_number(:errors, greater_than_or_equal_to: 0)
    |> validate_change(:details, &Validation.validate_safe/2)
    |> validate_change(:params, &Validation.validate_safe/2)
    |> with_foreign_key_constraint()
  end

  defp add_assoc(%{changes: %{parent_id: parent_id}} = changeset, _impl)
       when not is_nil(parent_id),
       do: changeset

  defp add_assoc(%{data: %{parent_id: parent_id}} = changeset, _impl)
       when not is_nil(parent_id),
       do: changeset

  defp add_assoc(changeset, implementation),
    do: put_assoc(changeset, :implementation, implementation)

  defp put_date(%{params: %{"date" => value}} = changeset) do
    # Standard datetime formats will be cast correctly by Ecto, we only need to
    # transform non-standard formats (YYYY-MM-DD or YYYY-MM-DD-HH-MM-SS).
    case DateParser.parse(value, [:utc_date, :legacy]) do
      {:ok, datetime, _} -> put_change(changeset, :date, datetime)
      _ -> cast(changeset, %{date: value}, [:date])
    end
  end

  defp put_date(changeset), do: changeset

  defp maybe_put_result(%{changes: %{result: _result}} = changeset), do: changeset

  defp maybe_put_result(changeset) do
    with records when is_integer(records) <- get_change(changeset, :records),
         errors when is_integer(errors) <- get_change(changeset, :errors),
         result_type when result_type != nil <- get_result_type(changeset) do
      result = calculate_quality(records, errors, result_type)
      put_change(changeset, :result, result)
    else
      _result -> changeset
    end
  end

  defp get_result_type(%{data: %{result_type: result_type}}) when not is_nil(result_type),
    do: result_type

  defp get_result_type(%{changes: %{result_type: result_type}}) when not is_nil(result_type),
    do: result_type

  defp get_result_type(changeset), do: get_change(changeset, :result_type)

  defp calculate_quality(0, _errors, _result_type), do: 0

  # deviation: percentage of errored records
  defp calculate_quality(records, errors, "deviation") do
    errors
    |> Decimal.mult(100)
    |> Decimal.div(records)
  end

  # percentage:    percentage of good records
  # errors number: could be either percentage of good or bad records. Keeping
  #                percentage of good records to maintain compatibility.
  defp calculate_quality(records, errors, result_type)
       when result_type in ["errors_number", "percentage"] do
    records
    |> Decimal.sub(errors)
    |> Decimal.abs()
    |> Decimal.mult(100)
    |> Decimal.div(records)
  end

  defp add_validations(%{data: %{parent_id: parent_id}} = changeset) when not is_nil(parent_id) do
    validate_required(changeset, @segments_validations)
  end

  defp add_validations(%{changes: %{parent_id: _}} = changeset) do
    validate_required(changeset, @segments_validations)
  end

  defp add_validations(changeset) do
    validate_required(changeset, @rule_resuls_validations)
  end

  defp with_foreign_key_constraint(%{changes: %{parent_id: parent_id}} = changeset)
       when not is_nil(parent_id) do
    foreign_key_constraint(changeset, :parent_id)
  end

  defp with_foreign_key_constraint(%{data: %{parent_id: parent_id}} = changeset)
       when not is_nil(parent_id) do
    foreign_key_constraint(changeset, :parent_id)
  end

  # defp with_foreign_key_constraint(changeset) do
  #   foreign_key_constraint(changeset, :rule_id)
  # end
  defp with_foreign_key_constraint(changeset), do: changeset
end
