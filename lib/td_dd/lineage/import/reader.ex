defmodule TdDd.Lineage.Import.Reader do
  @moduledoc """
  Provides functions for reading a graph from CSV import files.
  """

  alias TdDd.Lineage.Import.Validations

  NimbleCSV.define(LineageParser, separator: ",", escape: "\"")

  @doc """
  Read a graph from two CSV files. `nodes_path` is the path of a CSV file
  containing information about the vertices of the graph, `rels_path` is the
  path of a CSV file containing information about the edges of the graph. The
  supported file format is a simplified version of Neo4J import format,
  supporting only string and boolean typed fields.
  """
  def read(nodes_path, rels_path, opts \\ []) do
    with {:ok, nodes, rels} <- read_records(nodes_path, rels_path, opts),
         {:ok, graph} <- create_graph(nodes, rels),
         %Validations{valid: true} <- Validations.validate(graph) do
      {:ok, graph}
    end
  end

  defp create_graph(nodes, rels) do
    graph =
      Enum.reduce(nodes, Graph.new(), fn {external_id, label}, g ->
        Graph.add_vertex(g, external_id, label)
      end)

    rels
    |> Enum.reduce(
      {graph, _missing_vertices = []},
      fn %{start_id: start_id, end_id: end_id, metadata: metadata, class: class},
         {g, missing_vertices} ->
        with {_, true} <- {start_id, Graph.has_vertex?(graph, start_id)},
             {_, true} <- {end_id, Graph.has_vertex?(graph, end_id)} do
          {Graph.add_edge(g, start_id, end_id, class: class, metadata: metadata),
           missing_vertices}
        else
          {id, false} -> {g, [id | missing_vertices]}
        end
      end
    )
    |> case do
      {graph, []} -> {:ok, graph}
      {_, missing_vertices} -> {:error, %{missing_vertices: Enum.uniq(missing_vertices)}}
    end
  end

  defp read_records(nodes_path, rels_path, opts) do
    nodes_task =
      Task.async(fn ->
        nodes_path
        |> read_csv(&record_to_node_transformer/1)
        |> Enum.uniq_by(fn {external_id, _label} -> external_id end)
      end)

    rels_task =
      Task.async(fn ->
        rels_path
        |> read_csv(&record_to_rel_transformer/1)
        |> Enum.uniq_by(fn %{start_id: start_id, end_id: end_id} -> {start_id, end_id} end)
      end)

    [nodes_task, rels_task]
    |> Task.yield_many(Keyword.get(opts, :timeout, 600_000))
    |> Enum.map(fn
      {task, nil} -> Task.shutdown(task, :brutal_kill)
      {_task, res} -> res
    end)
    |> case do
      [{:ok, nodes}, {:ok, rels}] -> {:ok, nodes, rels}
      _ -> {:error, :timeout}
    end
  end

  defp read_csv(path, transformer_fun) do
    path
    |> File.stream!()
    |> flow_records(transformer_fun)
  end

  defp flow_records(stream, transformer_fun) do
    transform =
      stream
      |> read_headers()
      |> transformer_fun.()

    stream
    |> Stream.drop(1)
    # line 1 is header, so index starts with 2
    |> Flow.from_enumerable()
    |> Flow.map(&parse_string/1)
    |> Flow.map(transform)
    |> Enum.to_list()
  end

  defp read_headers(stream) do
    stream
    |> Enum.at(0)
    |> parse_string()
  end

  defp parse_string(str) do
    str
    |> LineageParser.parse_string(skip_headers: false)
    |> hd()
  end

  defp record_to_node_transformer([_ | _] = headers) do
    header_fns =
      Enum.map(headers, fn header ->
        cond do
          String.ends_with?(header, ":ID") ->
            &{:external_id, &1}

          String.ends_with?(header, ":LABEL") ->
            &{:class, &1}

          header == "select_hidden:boolean" ->
            &{"hidden", &1 == "true"}

          String.ends_with?(header, ":boolean") ->
            &{String.replace_suffix(header, ":boolean", ""), &1 == "true"}

          true ->
            &{header, &1}
        end
      end)

    fn record ->
      header_fns
      |> Enum.zip(record)
      |> Enum.map(fn {f, value} -> f.(value) end)
      |> Enum.reject(fn
        {"hidden", false} -> true
        {"system_external_id", _} -> true
        _ -> false
      end)
      |> Map.new()
      |> Map.pop!(:external_id)
    end
  end

  defp record_to_rel_transformer([_ | _] = headers) do
    headers =
      Enum.map(headers, fn header ->
        cond do
          String.ends_with?(header, ":START_ID") -> :start_id
          String.ends_with?(header, ":END_ID") -> :end_id
          String.ends_with?(header, ":TYPE") -> :class
          true -> header
        end
      end)

    fn record ->
      headers
      |> Enum.zip(record)
      |> extract_metadata("m:")
      |> Map.new()
    end
  end

  defp extract_metadata([{:class, "CONTAINS"} | _] = map, _prefix), do: map

  defp extract_metadata(map, prefix) do
    metadata =
      map
      |> List.keyfind(:class, 0)
      |> case do
        {:class, "DEPENDS"} ->
          map
          |> Enum.filter(fn
            {k, _} when is_atom(k) -> false
            {k, _} -> String.starts_with?(k, prefix)
          end)
          |> Enum.reduce(%{}, fn
            {_k, ""}, acc ->
              acc

            {_k, nil}, acc ->
              acc

            {k, value}, acc ->
              k
              |> String.replace_leading(prefix, "")
              |> (&Map.merge(acc, %{&1 => value})).()
          end)

        {:class, _} ->
          %{}
      end

    [{:metadata, metadata} | map]
  end
end
