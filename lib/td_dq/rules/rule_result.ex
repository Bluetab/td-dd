defmodule TdDq.Rules.RuleResult do
  @moduledoc """
  Ecto Schema module for Data Quality Rule Results.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Decimal
  alias TdDq.DateParser
  alias TdDq.Executions.Execution
  alias TdDq.Implementations.Implementation
  alias TdDq.Rules.Rule

  @scale 2
  @valid_result_types Rule.valid_result_types()

  @typedoc "The result of a quality rule execution"
  @type t :: %__MODULE__{}

  schema "rule_results" do
    field(:date, :utc_datetime)
    field(:result, :decimal, precision: 5, scale: @scale)
    field(:errors, :integer)
    field(:records, :integer)
    field(:params, :map, default: %{})
    field(:row_number, :integer, virtual: true)
    field(:result_type, :string)
    field(:details, :map, default: %{})

    belongs_to(:implementation, Implementation)
    belongs_to(:rule, Rule)

    has_many(:execution, Execution, foreign_key: :result_id)

    timestamps()
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
      :details
    ])
    |> put_assoc(:implementation, implementation)
    |> put_date()
    |> put_result()
    |> validate_inclusion(:result_type, @valid_result_types)
    |> update_change(:result, &Decimal.round(&1, @scale, :floor))
    |> validate_required([:implementation, :date, :result, :result_type, :rule_id])
    |> validate_number(:records, greater_than_or_equal_to: 0)
    |> validate_number(:errors, greater_than_or_equal_to: 0)
    |> validate_number(:result, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> foreign_key_constraint(:rule_id)
  end

  defp put_date(%{params: %{"date" => value}} = changeset) do
    # Standard datetime formats will be cast correctly by Ecto, we only need to
    # transform non-standard formats (YYYY-MM-DD or YYYY-MM-DD-HH-MM-SS).
    case DateParser.parse(value, [:utc_date, :legacy]) do
      {:ok, datetime, _} -> put_change(changeset, :date, datetime)
      _ -> cast(changeset, %{date: value}, [:date])
    end
  end

  defp put_date(changeset), do: changeset

  defp put_result(%{} = changeset) do
    with records when is_integer(records) <- get_change(changeset, :records),
         errors when is_integer(errors) <- get_change(changeset, :errors),
         result_type when result_type != nil <-
           changeset.data.result_type || get_change(changeset, :result_type) do
      result = calculate_quality(records, errors, result_type)
      put_change(changeset, :result, result)
    else
      _result -> changeset
    end
  end

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
end
