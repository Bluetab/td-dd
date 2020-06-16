defmodule TdDq.Rules.RuleResult do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  alias Decimal
  alias TdDq.DateParser
  alias TdDq.Rules.RuleResult

  @scale 2

  schema "rule_results" do
    field(:implementation_key, :string)
    field(:date, :utc_datetime)
    field(:result, :decimal, precision: 5, scale: @scale)
    field(:parent_domains, :string, default: "")
    field(:errors, :integer)
    field(:records, :integer)
    field(:params, :map, default: %{})
    timestamps()
  end

  def changeset(%RuleResult{} = rule_result, params) do
    params =
      params
      |> format_date()
      |> format_result()

    rule_result
    |> cast(params, [
      :implementation_key,
      :date,
      :parent_domains,
      :result,
      :errors,
      :records,
      :params
    ])
    |> validate_required([:implementation_key, :date, :result])
    |> validate_number(:result, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
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
