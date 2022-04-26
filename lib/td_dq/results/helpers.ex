defmodule TdDq.Results.Helpers do
  alias TdDq.DateParser

  alias Decimal
  import Ecto.Changeset

  def put_date(%{params: %{"date" => value}} = changeset) do
    # Standard datetime formats will be cast correctly by Ecto, we only need to
    # transform non-standard formats (YYYY-MM-DD or YYYY-MM-DD-HH-MM-SS).
    case DateParser.parse(value, [:utc_date, :legacy]) do
      {:ok, datetime, _} -> put_change(changeset, :date, datetime)
      _ -> cast(changeset, %{date: value}, [:date])
    end
  end

  def put_date(changeset), do: changeset

  def maybe_put_result(%{changes: %{result: _result}} = changeset), do: changeset

  def maybe_put_result(changeset) do
    with records when is_integer(records) <- get_change(changeset, :records),
         errors when is_integer(errors) <- get_change(changeset, :errors),
         result_type when result_type != nil <- get_result_type(changeset) do

      result = calculate_quality(records, errors, result_type)
      put_change(changeset, :result, result)
    else
      _result -> changeset
    end
  end

  defp get_result_type(%{data: %{result_type: result_type}}) when not is_nil(result_type), do: result_type
  defp get_result_type(%{changes: %{result_type: result_type}}) when not is_nil(result_type), do: result_type
  defp get_result_type(%{changes: %{rule_result: %{data: %{result_type: result_type}}}}) when not is_nil(result_type) , do: result_type
  defp get_result_type(changeset), do: get_change(changeset, :result_type)


  def calculate_quality(0, _errors, _result_type), do: 0

  # deviation: percentage of errored records
  def calculate_quality(records, errors, "deviation") do
    errors
    |> Decimal.mult(100)
    |> Decimal.div(records)
  end

  # percentage:    percentage of good records
  # errors number: could be either percentage of good or bad records. Keeping
  #                percentage of good records to maintain compatibility.
  def calculate_quality(records, errors, result_type)
      when result_type in ["errors_number", "percentage"] do
    records
    |> Decimal.sub(errors)
    |> Decimal.abs()
    |> Decimal.mult(100)
    |> Decimal.div(records)
  end
end
