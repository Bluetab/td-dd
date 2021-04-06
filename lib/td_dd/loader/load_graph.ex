defmodule TdDd.Loader.LoadGraph do
  @moduledoc """
  Loader multi support for extending the graph with ancestry entries for a
  specified external_id and parent_external_id.
  """
  alias TdDd.DataStructures.Ancestry
  alias TdDd.DataStructures.MerkleGraph
  alias TdDd.DataStructures.RelationTypes

  @spec load_graph(atom, map, [map], [map], Keyword.t()) ::
          {:error, :invalid_graph | :root_mismatch} | {:ok, Graph.t()}
  def load_graph(_repo, %{} = _changes, structure_records, relation_records, opts) do
    load_graph(structure_records, relation_records, opts)
  end

  @spec load_graph([map], [map], Keyword.t()) ::
          {:error, :invalid_graph | :root_mismatch} | {:ok, Graph.t()}
  def load_graph(structure_records, relation_records, opts) do
    with {:ok, graph} <- MerkleGraph.new(structure_records, relation_records) do
      include_ancestry(graph, opts[:external_id], opts[:parent_external_id])
    end
  end

  defp include_ancestry(graph, nil, nil) do
    {:ok, graph}
  end

  defp include_ancestry(graph, external_id, parent_external_id) do
    case MerkleGraph.root(graph) do
      ^external_id ->
        ancestor_records =
          external_id
          |> Ancestry.get_ancestor_records(parent_external_id)
          |> RelationTypes.with_relation_types()

        MerkleGraph.add(graph, ancestor_records)

      nil ->
        {:error, :invalid_graph}

      _ ->
        {:error, :root_mismatch}
    end
  end
end
