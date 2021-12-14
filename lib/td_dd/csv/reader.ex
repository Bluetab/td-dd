defmodule TdDd.CSV.Reader do
  @moduledoc """
  Module to read Data Structure CSV
  """
  alias Ecto.Changeset
  alias TdDd.DataStructures

  NimbleCSV.define(CsvParser, separator: ";", escape: "\"")

  @truthy_values ["t", "true", "y", "yes", "on", "1"]

  def read_csv(stream, options \\ []) do
    separator = Keyword.get(options, :separator, ?;)
    domain_external_ids = Keyword.get(options, :domain_external_ids)
    system_map = Keyword.get(options, :system_map)
    domain = Keyword.get(options, :domain)

    records =
      stream
      |> read_records(separator)
      |> with_domain_id(domain, domain_external_ids)
      |> with_system_id(system_map)
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

  defp read_records(stream, ?; = _separator) do
    csv = CsvParser.parse_stream(stream, skip_headers: false)
    headers = Enum.at(csv, 0)

    csv
    |> Enum.drop(1)
    |> parse_chunk(headers)
  end

  defp parse_chunk(chunk, headers) do
    Enum.map(chunk, fn fields ->
      headers
      |> Enum.zip(fields)
      |> Map.new()
    end)
  end

  defp with_domain_id(records, nil, external_ids) do
    with_domain_id(records, external_ids)
  end

  defp with_domain_id(records, domain, external_ids) do
    Enum.map(records, &DataStructures.put_domain_id(&1, external_ids, domain))
  end

  defp with_domain_id(records, external_ids) do
    Enum.map(records, &DataStructures.put_domain_id(&1, external_ids))
  end

  defp with_system_id(records, nil = _system_map), do: records

  defp with_system_id(records, system_map) do
    Enum.map(records, &add_system_id(&1, system_map))
  end

  defp add_system_id(%{"system" => system} = record, system_map) do
    system_id = Map.get(system_map, system)
    Map.put(record, "system_id", system_id)
  end

  defp add_system_id(record, _system_map) do
    Map.put(record, "system_id", nil)
  end

  def csv_to_map(record, options \\ []) do
    defaults = Keyword.get(options, :defaults, %{}) || %{}
    types = Keyword.get(options, :schema, %{}) || %{}
    required = Keyword.get(options, :required, [])
    booleans = Keyword.get(options, :booleans, [])
    truthy_values = Keyword.get(options, :truthy_values, @truthy_values)

    record
    |> values_to_bools(booleans, truthy_values)
    |> changeset(defaults, types, required)
  end

  def changeset(record, defaults, %{metadata: :map, mutable_metadata: :map} = types, required) do
    meta = extract_meta(record, "m:")
    mutable_meta = extract_meta(record, "mm:")

    {defaults, types}
    |> Changeset.cast(record, Map.keys(types))
    |> Changeset.change(%{metadata: meta})
    |> Changeset.change(%{mutable_metadata: mutable_meta})
    |> Changeset.validate_required(required)
    |> Changeset.apply_action(:update)
  end

  def changeset(record, defaults, %{value: :map} = types, required) do
    profiling = extract_profiling(record)

    {defaults, types}
    |> Changeset.cast(record, Map.keys(types))
    |> Changeset.change(%{value: profiling})
    |> Changeset.validate_required(required)
    |> Changeset.apply_action(:update)
  end

  def changeset(record, defaults, types, required) do
    {defaults, types}
    |> Changeset.cast(record, Map.keys(types))
    |> Changeset.validate_required(required)
    |> Changeset.apply_action(:update)
  end

  def extract_meta(map, prefix) do
    map
    |> Enum.filter(fn {k, _} -> String.starts_with?(k, prefix) end)
    |> Enum.reduce(%{}, &reduce_metadata(&1, &2, prefix))
  end

  def extract_profiling(map) do
    map
    |> Enum.filter(fn {k, _} -> k != "external_id" end)
    |> Enum.reduce(%{}, &reduce_metadata(&1, &2, "m:"))
  end

  defp reduce_metadata({_, ""}, acc, _prefix), do: acc

  defp reduce_metadata({k, v}, %{} = acc, prefix) do
    [h | t] =
      k
      |> String.replace_leading(prefix, "")
      |> String.split(".")
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
