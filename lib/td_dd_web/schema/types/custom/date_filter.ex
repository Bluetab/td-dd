defmodule TdDdWeb.Schema.Types.Custom.DateFilter do
  @moduledoc """
  The DateFilter scalar type represents an operators for date filtering

  This type has the following characteristics:

    1. Only gt, lt or eq keys are permitted
    2. If the eq key exists, can't be another key
    3. If the keys gt and lt are present at the same time, the value of lt can't be less than the
       value of gt and the value of gt can't be greater than lt
  """
  use Absinthe.Schema.Notation

  scalar :date_filter, name: "DateFilter", open_ended: true do
    description("""
    The `DateFilter` represents an operators for date filtering

    This type has the following characteristics:

    1. Only gt, lt or eq keys are permitted
    2. If the eq key exists, can't be another key
    3. If the keys gt and lt are present at the same time, the value of lt can't be less than the
       value of gt and the value of gt can't be greater than lt
    """)
    parse(&decode/1)
    serialize(&encode/1)
  end

  @spec decode(Absinthe.Blueprint.Input.Object.t()) :: {:ok, term()} | :error
  @spec decode(Absinthe.Blueprint.Input.Null.t()) :: {:ok, nil}
  defp decode(%Absinthe.Blueprint.Input.Object{fields: fields}) do
    fields
    |> Enum.map(fn %{input_value: %{normalized: %{value: value}}, name: name} ->
      {String.to_atom(name), value}
    end)
    |> Map.new
    |> validate_date_filter
  end

  defp decode(%Absinthe.Blueprint.Input.Null{}) do
    {:ok, nil}
  end

  defp decode(_) do
    :error
  end

  defp encode(_value), do: :error

  defp validate_date_filter(value) do
    with {:ok, value} <- valitate_keys(value),
         {:ok, value} <- validate_eq(value),
         {:ok, value} <- validate_gt_lt(value) do
      {:ok, value}
    else
      _ -> :error
    end

  end

  defp valitate_keys(value) do
    if (length(Map.keys(value) -- [:eq, :lt, :gt]) > 0) do
      :error
    else
      {:ok, value}
    end
  end

  defp validate_eq(value) do
    value_n_keys = map_size(value)
    case Map.has_key?(value, :eq) do
      true when value_n_keys == 1 ->
        {:ok, value}
      false ->
        {:ok, value}
      _ ->
        :error
    end
  end

  defp validate_gt_lt(value) do
    case {Map.has_key?(value, :gt), Map.has_key?(value, :lt)} do
      {true, true} ->
        gt = Date.from_iso8601!(Map.get(value, :gt))
        lt = Date.from_iso8601!(Map.get(value, :lt))
        case Date.compare(gt, lt) do
          :lt -> {:ok, value}
          _ -> :error
        end
      _ ->
        {:ok, value}
    end
  end

end
