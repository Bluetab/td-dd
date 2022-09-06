defmodule TdDd.DataStructures.MerkleGraph do
  @moduledoc """
  This module transforms data structure bulk load records into a Merkle DAG,
  propagating the hashes of each node from the bottom up.
  """

  alias Graph.Traversal
  alias TdDd.DataStructures.Hasher

  require Logger

  @doc """
  Returns a list of parent vertices for a given vertex
  """
  def parents(graph, external_id) do
    Graph.in_neighbours(graph, external_id)
  end

  @doc """
  Returns a list of in edges for a given vertex
  """
  def in_edges(graph, external_id) do
    graph
    |> Graph.in_edges(external_id)
    |> Enum.map(&Graph.edge(graph, &1))
  end

  @doc """
  Returns a list of out edges for a given vertex
  """
  def out_edges(graph, external_id) do
    graph
    |> Graph.out_edges(external_id)
    |> Enum.map(&Graph.edge(graph, &1))
  end

  @doc """
  Returns a list of child vertices for a given vertex
  """
  def children(graph, external_id) do
    Graph.out_neighbours(graph, external_id)
  end

  @doc """
  Returns a list of descendent vertices for a set of vertices
  """
  def descendents(graph, external_ids)

  def descendents(graph, external_ids) when is_list(external_ids) do
    Traversal.reachable(external_ids, graph)
  end

  def descendents(graph, external_id) do
    descendents(graph, [external_id])
  end

  @doc """
  Returns a topological ordering of vertices in a graph (see
  `Traversal.topsort/1`)
  """
  def top_down(graph) do
    Traversal.topsort(graph)
  end

  @doc """
  Returns an inverse topological ordering of vertices in a graph (see
  `Traversal.topsort/1`)
  """
  def bottom_up(graph) do
    graph
    |> top_down()
    |> Enum.reverse()
  end

  @doc """
  Returns the id of the arborescence root of a graph, or nil if the graph is not
  an arborescence
  """
  def root(graph) do
    Traversal.arborescence_root(graph)
  end

  @doc """
  Adds structure and relation records to a directed acyclic graph. Propagates
  hashes bottom-up (see `TdDd.DataStructures.Hasher` for details).
  """
  def new(structures, relations) do
    graph = Graph.new([], acyclic: true)

    with {:ok, graph} <- Enum.reduce_while(structures, {:ok, graph}, &add_structure/2),
         {:ok, graph} <- Enum.reduce_while(relations, {:ok, graph}, &add_relation/2) do
      {:ok, propagate_hashes(graph)}
    end
  end

  @doc """
  Add vertices and edges to an existing digraph. This is used to recalculate
  hashes of ancestors when a data structure ancestry is changed (i.e. when it is
  moved from one parent to another).

  The first argument is an existing digraph. Validation is performed before
  adding the vertices to ensure that none of the vertices to add currently
  exists in the graph

  The second argument is a tuple of:

    - `structures` - a list of tuples {external_id, struct} `relations`
    - a list of relations %{parent_external_id, child_external_id}

  Hashes will be propagated for any structures without the label `:ghash.`
  """
  @spec add(Graph.t(), nil | {[map], [map]}) :: {:ok, Graph.t()}
  def add(graph, records)

  def add(graph, nil), do: {:ok, graph}

  def add(graph, {[], []}), do: {:ok, graph}

  def add(graph, {structures, relations}) do
    with :ok <- validate_graph(graph, structures),
         {:ok, graph} <- Enum.reduce_while(structures, {:ok, graph}, &add_structure/2),
         {:ok, graph} <- Enum.reduce_while(relations, {:ok, graph}, &add_relation/2) do
      # identify vertices to be refreshed
      to_refresh =
        structures
        |> Enum.reject(fn {_, record} -> Map.has_key?(record, :ghash) end)
        |> Enum.map(fn {id, _} -> id end)

      # update their hashes
      graph =
        graph
        |> bottom_up()
        |> Enum.filter(&Enum.member?(to_refresh, &1))
        |> Enum.reduce(graph, &propagate_hashes/2)

      {:ok, graph}
    end
  end

  @doc """
  Reads a record with a given external_id from a graph, including its hashes in the
  resulting struct.
  """
  def get(graph, external_id) do
    case Graph.vertex_label(graph, external_id) do
      %{record: record, lhash: _} = label ->
        label
        |> Map.take([:hash, :lhash, :ghash])
        |> Map.merge(record)
    end
  end

  @spec validate_graph(Graph.t(), [map]) :: :ok
  defp validate_graph(graph, structure_records) do
    structure_records
    |> Enum.map(fn {external_id, _} -> external_id end)
    |> Enum.map(&Graph.vertex(graph, &1))
    |> Enum.find(& &1)
    |> validate_nil()
  end

  defp validate_nil(nil), do: :ok

  defp validate_nil(%Graph.Vertex{id: external_id}) do
    message = "vertex exists: #{external_id}"
    Logger.warn(message)
    {:error, message}
  end

  defp propagate_hashes(g) do
    # Calculate hashes from bottom up
    g
    |> bottom_up()
    |> Enum.reduce(g, &propagate_hashes/2)
  end

  def propagate_hashes(id, g) do
    parent_label = Graph.vertex_label(g, id)

    child_labels =
      g
      |> Graph.out_edges(id)
      |> Enum.map(&Graph.edge(g, &1))
      |> Enum.map(fn %{v2: v2, label: label} ->
        g
        |> Graph.vertex_label(v2)
        |> Map.merge(label)
      end)

    lhash = local_hash([parent_label | child_labels])
    ghash = global_hash([parent_label | child_labels])

    Graph.put_label(g, id, lhash: lhash, ghash: ghash)
  end

  # Local hash is hash of parent record and immediate child records
  def local_hash(vertices) do
    vertices
    |> Enum.group_by(&Map.get(&1, :relation_type_id))
    |> Enum.flat_map(fn {relation_type_id, labels} ->
      hashes = Enum.map(labels, & &1[:hash])
      if relation_type_id, do: [Hasher.hash(relation_type_id) | hashes], else: hashes
    end)
    |> Hasher.hash()
  end

  # Global hash is hash of parent record and all descendent records
  def global_hash([parent | children]) do
    child_hashes =
      children
      |> Enum.group_by(&Map.get(&1, :relation_type_id))
      |> Enum.flat_map(fn {relation_type_id, labels} ->
        hashes = Enum.map(labels, &(&1[:ghash] || &1[:hash]))
        if relation_type_id, do: [Hasher.hash(relation_type_id) | hashes], else: hashes
      end)

    [parent[:hash] | child_hashes]
    |> Hasher.hash()
  end

  defp add_structure(structure, {:ok, %Graph{} = graph}) do
    add_structure(structure, graph)
  end

  defp add_structure({external_id, %{} = struct}, graph) do
    labels =
      struct
      |> Map.take([:hash, :lhash, :ghash])
      |> Map.put(:record, Hasher.to_hashable(struct))
      |> Keyword.new()

    add_vertex(external_id, graph, labels)
  end

  defp add_structure(structure, graph) do
    hash = Hasher.hash(structure)

    structure
    |> get_id()
    |> add_vertex(graph, record: structure, hash: hash)
  end

  defp add_relation(ids, {:ok, %Graph{} = graph}) do
    add_relation(ids, graph)
  end

  defp add_relation(%{parent_external_id: id, child_external_id: id}, _graph) do
    message = "reflexive relations are not permitted (#{id})"
    Logger.warn(message)
    {:halt, {:error, message}}
  end

  defp add_relation(
         %{
           parent_external_id: parent,
           child_external_id: child,
           relation_type_id: relation_type_id
         },
         graph
       ) do
    {:cont, {:ok, Graph.add_edge(graph, parent, child, relation_type_id: relation_type_id)}}
  end

  defp add_vertex(id, graph, labels) do
    if Graph.has_vertex?(graph, id) do
      message = "duplicate #{id}"
      Logger.warn(message)
      {:halt, {:error, message}}
    else
      {:cont, {:ok, Graph.add_vertex(graph, id, labels)}}
    end
  end

  defp get_id(%{parent_external_id: parent_external_id, child_external_id: child_external_id}) do
    {:relation, parent_external_id, child_external_id}
  end

  defp get_id(%{external_id: external_id}) do
    external_id
  end
end
