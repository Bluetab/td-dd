defmodule TdDd.DataStructures.Graph do
  @moduledoc """
  This module transforms data structure bulk load records into a directed acyclic graph,
  and propagates the hashes of each node from the bottom up.
  """

  alias TdDd.DataStructures.Hasher

  require Logger

  @doc """
  Create a new directed acyclic graph (see :digraph.new/1)
  """
  def new(options \\ [:acyclic]) do
    :digraph.new(options)
  end

  @doc """
  Delete a digraph (see :digraph.new/1)
  """
  def delete(graph) do
    :digraph.delete(graph)
  end

  @doc """
  Returns a list of parent vertices for a given vertex
  """
  def parents(graph, external_id) do
    graph
    |> :digraph.in_edges(external_id)
    |> Enum.map(&:digraph.edge(graph, &1))
    |> Enum.map(fn {_, parent, _, labels} -> {parent, labels} end)
  end

  @doc """
  Returns a list of child vertices for a given vertex
  """
  def children(graph, external_id) do
    graph
    |> :digraph.out_edges(external_id)
    |> Enum.map(&:digraph.edge(graph, &1))
    |> Enum.map(fn {_, _, child, labels} -> {child, labels} end)
  end

  @doc """
  Returns a list of descendent vertices for a set of vertices
  """
  def descendents(graph, external_ids) when is_list(external_ids) do
    :digraph_utils.reachable(external_ids, graph)
  end

  @doc """
  Returns a list of descendent vertices for a given vertex
  """
  def descendents(graph, external_id) do
    descendents(graph, [external_id])
  end

  @doc """
  Returns a topological ordering of vertices in a graph (see :digraph_utils.topsort)
  """
  def top_down(graph) do
    :digraph_utils.topsort(graph)
  end

  @doc """
  Returns an inverse topological ordering of vertices in a graph (see :digraph_utils.topsort)
  """
  def bottom_up(graph) do
    graph
    |> top_down()
    |> Enum.reverse()
  end

  @doc """
  Returns the id of the arborescence root of a graph, or nil if the graph is not an arborescence
  """
  def root(graph) do
    case :digraph_utils.arborescence_root(graph) do
      {:yes, id} -> id
      _ -> nil
    end
  end

  @doc """
  Adds structure and relation records to a directed acyclic graph.
  Propagates hashes bottom-up (see `TdDd.DataStructure.Hasher` for details).
  """
  def add(graph, structures, relations) do
    graph = Enum.reduce(structures, graph, &add_structure/2)
    graph = Enum.reduce(relations, graph, &add_relation/2)
    graph = propagate_hashes(graph)
    {:ok, graph}
  end

  @doc """
  Add vertices and edges to an existing digraph. This is used to recalculate
  hashes of ancestors when a data structure ancestry is changed (i.e. when
  it is moved from one parent to another).

  The first argument is an existing digraph. Validation is performed
  before adding the vertices to ensure that none of the vertices to add
  currently exists in the graph

  The second argument is a tuple of:

  `structures` - a list of tuples {external_id, struct}
  `relations` - a list of relations %{parent_external_id, child_external_id}

  Hashes will be propagated for any structures without the label
  :ghash.
  """
  def add(graph, records)

  def add(graph, nil), do: {:ok, graph}

  def add(graph, {[], []}), do: {:ok, graph}

  def add(graph, {structures, relations}) do
    case validate_graph(graph, structures) do
      :ok ->
        graph = Enum.reduce(structures, graph, &add_structure/2)
        graph = Enum.reduce(relations, graph, &add_relation/2)

        # identify vertices to be refreshed
        to_refresh =
          structures
          |> Enum.reject(fn {_, record} -> Map.has_key?(record, :ghash) end)
          |> Enum.map(fn {id, _} -> id end)

        # update their hashes
        graph
        |> bottom_up()
        |> Enum.filter(&Enum.member?(to_refresh, &1))
        |> Enum.each(&propagate_hashes(&1, graph))

        {:ok, graph}

      e ->
        e
    end
  end

  @doc """
  Reads a record with a given external_id from a graph, including it's hashes in the
  resulting struct.
  """
  def get(graph, external_id) do
    case :digraph.vertex(graph, external_id) do
      {^external_id, labels} ->
        labels
        |> Keyword.get(:record)
        |> Map.put(:hash, Keyword.get(labels, :hash))
        |> Map.put(:lhash, Keyword.get(labels, :lhash))
        |> Map.put(:ghash, Keyword.get(labels, :ghash))
    end
  end

  defp validate_graph(graph, structure_records) do
    structure_records
    |> Enum.map(fn {external_id, _} -> external_id end)
    |> Enum.map(&:digraph.vertex(graph, &1))
    |> Enum.find(& &1)
    |> validate_nil()
  end

  defp validate_nil(nil), do: :ok

  defp validate_nil({external_id, _labels}) do
    Logger.warn("#{external_id} :vertex_exists")
    raise ":vertex_exists"
    :vertex_exists
  end

  defp get_edge_child_vertex(
         g,
         {_, _, external_id, [relation_type_id: rel_type_id, relation_type_name: rel_type_name]}
       ) do
    {_, keyword} = :digraph.vertex(g, external_id)

    keyword =
      case rel_type_name do
        "default" ->
          keyword

        _ ->
          rhash =
            keyword
            |> Keyword.get(:hash)
            |> Kernel.<>("#{rel_type_id}")
            |> Hasher.hash()

          rghash =
            keyword
            |> Keyword.get(:ghash)
            |> Kernel.<>("#{rel_type_id}")
            |> Hasher.hash()

          keyword
          |> Keyword.put(:rhash, rhash)
          |> Keyword.put(:rghash, rghash)
      end

    {external_id, keyword}
  end

  defp propagate_hashes(g) do
    # Calculate hashes from bottom up
    g
    |> bottom_up()
    |> Enum.each(&propagate_hashes(&1, g))

    g
  end

  def propagate_hashes(id, g) do
    parent = :digraph.vertex(g, id)

    children =
      g
      |> :digraph.out_edges(id)
      |> Enum.map(&:digraph.edge(g, &1))
      |> Enum.map(&get_edge_child_vertex(g, &1))

    lhash = local_hash([parent | children])
    ghash = global_hash([parent | children])

    {^id, labels} = parent

    labels =
      labels
      |> Keyword.put(:lhash, lhash)
      |> Keyword.put(:ghash, ghash)

    :digraph.add_vertex(g, id, labels)
  end

  # Local hash is hash of parent record and immediate child records
  def local_hash(vertices) do
    vertices
    |> Enum.map(fn {_, labels} -> labels end)
    |> Enum.map(&(&1[:rhash] || &1[:hash]))
    |> Hasher.hash()
  end

  # Global hash is hash of parent record and all descendent records
  def global_hash([parent | children]) do
    {_, labels} = parent

    child_hashes =
      children
      |> Enum.map(fn {_, labels} -> labels end)
      |> Enum.map(&(&1[:rghash] || &1[:ghash] || &1[:hash]))

    [labels[:hash] | child_hashes]
    |> Hasher.hash()
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

  defp add_relation(relation, graph) do
    parent = parent_vertex(relation, graph)
    child = child_vertex(relation, graph)
    add_parent_child(graph, parent, child, relation)
  end

  defp add_parent_child(_graph, id, id, _relation) do
    raise("reflexive relations are not permitted (#{id})")
  end

  defp add_parent_child(graph, parent, child, relation) do
    labels =
      relation
      |> Map.take([:relation_type_id, :relation_type_name])
      |> Keyword.new()

    :digraph.add_edge(graph, parent, child, labels)
    graph
  end

  defp structure_vertex(rec, graph) do
    id =
      rec
      |> Map.take([:external_id])
      |> get_id()

    {v, _} = :digraph.vertex(graph, id)
    v
  end

  defp parent_vertex(%{parent_external_id: external_id}, graph) do
    %{external_id: external_id}
    |> structure_vertex(graph)
  end

  defp child_vertex(%{child_external_id: external_id}, graph) do
    %{external_id: external_id}
    |> structure_vertex(graph)
  end

  defp add_vertex(id, graph, labels) do
    case :digraph.vertex(graph, id) do
      false ->
        :digraph.add_vertex(graph, id, labels)
        graph

      _ ->
        raise("duplicate #{id}")
    end
  end

  defp get_id(%{
         parent_external_id: parent_external_id,
         child_external_id: child_external_id
       }) do
    {:relation, parent_external_id, child_external_id}
  end

  defp get_id(%{external_id: external_id}) do
    external_id
  end
end
