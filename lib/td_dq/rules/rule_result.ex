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

  @scale 2

  schema "rule_results" do
    belongs_to(:execution, Execution)
    field(:implementation_key, :string)
    field(:date, :utc_datetime)
    field(:result, :decimal, precision: 5, scale: @scale)
    field(:errors, :integer)
    field(:records, :integer)
    field(:params, :map, default: %{})
    field(:row_number, :integer, virtual: true)

    has_one(:implementation, Implementation,
      foreign_key: :implementation_key,
      references: :implementation_key
    )

    has_one(:rule, through: [:implementation, :rule])
    timestamps()
  end

  def changeset(%{} = params) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(%__MODULE__{} = rule_result, params) do
    params =
      params
      |> format_date()
      |> format_result()

    rule_result
    |> cast(params, [
      :execution_id,
      :implementation_key,
      :date,
      :result,
      :errors,
      :records,
      :params,
      :row_number
    ])
    |> validate_required([:implementation_key, :date, :result])
    |> validate_number(:result, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> foreign_key_constraint(:execution_id)
  end

  defp format_date(%{"date" => date} = params) do
    # Standard datetime formats will be handled by Ecto, we only need to
    # transform non-standard formats (YYYY-MM-DD or YYYY-MM-DD-HH-MM-SS).
    case DateParser.parse(date, [:utc_date, :legacy]) do
      {:ok, datetime, _} -> Map.put(params, "date", datetime)
      _ -> params
    end
  end

  defp format_date(params), do: params

  defp format_result(%{"result" => result} = params) when is_float(result) do
    result = Decimal.round(Decimal.from_float(result), @scale, :floor)
    Map.put(params, "result", result)
  end

  defp format_result(params), do: params
end
