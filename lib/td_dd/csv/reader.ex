defmodule TdDd.CSV.Reader do
  @moduledoc """
    Module to read Data Structure CSV
  """
  alias Ecto.Changeset
  alias TdDd.DataStructures

  @truthy_values ["t", "true", "y", "yes", "on", "1"]

  def read_csv(stream, options \\ []) do
    separator = Keyword.get(options, :separator, ?;)
    domain_map = Keyword.get(options, :domain_map)

    records =
      stream
      |> read_records(separator, domain_map)
      |> Enum.map(&csv_to_map(&1, options))

    {oks, errors} =
      records
      # line 1 is header, so index starts with 2
      |> Enum.with_index(2)
      |> Enum.split_with(fn {{res, _}, _} -> res == :ok end)

    case errors do
      [] ->
        {:ok, Enum.map(oks, fn {{_, r}, _} -> r end)}

      _ ->
        {:error, Enum.map(errors, fn {{_, r}, index} -> {r, index} end)}
    end
  end

  defp read_records(stream, separator, nil = _domain_map) do
    stream
    |> CSV.decode!(separator: separator, headers: true)
    |> Enum.to_list()
  end

  defp read_records(stream, separator, domain_map) do
    stream
    |> read_records(separator, nil)
    |> Enum.map(&DataStructures.add_domain_id(&1, domain_map))
  end

  def csv_to_map(record, options \\ []) do
    data = Keyword.get(options, :defaults, %{})
    types = Keyword.get(options, :schema, %{})
    required = Keyword.get(options, :required, [])
    booleans = Keyword.get(options, :booleans, [])
    truthy_values = Keyword.get(options, :truthy_values, @truthy_values)

    params =
      record
      |> values_to_bools(booleans, truthy_values)

    meta = extract_meta(params)

    {data, types}
    |> Changeset.cast(params, Map.keys(types))
    |> Changeset.change(%{metadata: meta})
    |> Changeset.validate_required(required)
    |> Changeset.apply_action(:update)
  end

  def extract_meta(map) do
    map
    |> Enum.filter(fn {k, _} -> String.starts_with?(k, "m:") end)
    |> Enum.reduce(%{}, &reduce_metadata/2)
  end

  defp reduce_metadata({_, ""}, acc), do: acc

  defp reduce_metadata({k, v}, %{} = acc) do
    [h | t] =
      k
      |> String.replace_leading("m:", "")
      |> String.split(".")
      |> Enum.map(&String.to_atom/1)
      |> Enum.reverse()

    t
    |> Enum.reduce(%{h => v}, fn k, acc -> %{k => acc} end)
    |> Map.merge(acc, &merge_recursive/3)
  end

  defp merge_recursive(_k, %{} = v1, %{} = v2) do
    Map.merge(v1, v2, &merge_recursive/3)
  end

  def values_to_bools(map, keys, truthy_values \\ @truthy_values) do
    keys
    |> Enum.reduce(map, fn k, acc -> values_to_bool(acc, k, truthy_values) end)
  end

  def values_to_bool(map, key, truthy_values \\ @truthy_values) do
    {value, map} = Map.pop(map, key)

    case value do
      nil ->
        map

      "" ->
        map

      v ->
        bool = Enum.member?(truthy_values, String.downcase(v))
        Map.put(map, key, bool)
    end
  end
end
