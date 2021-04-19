defmodule TdDq.Rules.RuleResult do
  @moduledoc """
  Ecto Schema module for Data Quality Rule Results.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Decimal
  alias TdDq.DateParser
  alias TdDq.Executions.Execution
  alias TdDq.Rules.Implementations.Implementation
  alias TdDq.Rules.Rule

  @scale 2
  @valid_result_types Rule.valid_result_types()

  schema "rule_results" do
    field(:implementation_key, :string)
    field(:date, :utc_datetime)
    field(:result, :decimal, precision: 5, scale: @scale)
    field(:errors, :integer)
    field(:records, :integer)
    field(:params, :map, default: %{})
    field(:row_number, :integer, virtual: true)
    field(:result_type, :string)

    has_one(:implementation, Implementation,
      foreign_key: :implementation_key,
      references: :implementation_key
    )

    has_one(:rule, through: [:implementation, :rule])

    has_many(:execution, Execution, foreign_key: :result_id)

    timestamps()
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = struct, params) do
    struct
    |> cast(params, [
      :implementation_key,
      :result,
      :errors,
      :records,
      :params,
      :row_number,
      :result_type
    ])
    |> put_date()
    |> put_result()
    |> validate_inclusion(:result_type, @valid_result_types)
    |> update_change(:result, &Decimal.round(&1, @scale, :floor))
    |> validate_required([:implementation_key, :date, :result, :result_type])
    |> validate_number(:records, greater_than_or_equal_to: 0)
    |> validate_number(:errors, greater_than_or_equal_to: 0)
    |> validate_number(:result, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
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
         errors when is_integer(errors) <- get_change(changeset, :errors) do
      result = calculate_quality(records, errors)
      put_change(changeset, :result, result)
    else
      _result -> changeset
    end
  end

  defp calculate_quality(0, _errors), do: 0

  defp calculate_quality(records, errors) do
    records
    |> Decimal.sub(errors)
    |> Decimal.abs()
    |> Decimal.mult(100)
    |> Decimal.div(records)
  end
end
