defmodule TdDd.DataStructures.Graph do
  @moduledoc """
  This module transforms data structure bulk load records into a directed acyclic graph,
  and propagates the hashes of each node from the bottom up.
  """

  alias TdDd.DataStructures.Hasher

  require Logger

  @doc """
  Creates a new directed acyclic graph of structures and their relations.
  Propagates hashes bottom-up (see `TdDd.DataStructure.Hasher` for details).
  """
  def new(structures, relations) do
    graph = Enum.reduce(structures, :digraph.new([:acyclic]), &add_structure/2)
    graph = Enum.reduce(relations, graph, &add_relation/2)

    propagate_hashes(graph)
  end

  def new(structures, relations, nil) do
    {:ok, new(structures, relations)}
  end

  def new(structures, relations, root_id) do
    with graph <- new(structures, relations),
         {:yes, ^root_id} <- :digraph_utils.arborescence_root(graph) do
      {:ok, graph}
    else
      {:yes, _} -> {:error, :root_mismatch}
      :no -> {:error, :invalid_graph}
      e -> e
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

  @doc """
  Add vertices and edges to an existing digraph. This is used to recalculate
  hashes of ancestors when a data structure ancestry is changed (i.e. when
  it is moved from one parent to another).

  The first argument is a tuple of:

  `structures` - a list of tuples {external_id, struct}
  `relations` - a list of relations %{parent_external_id, child_external_id}

  The second argument is an existing digraph. Validation is performed
  before adding the vertices to ensure that none of the vertices to add
  currently exists in the graph

  Hashes will be propagated for any structures without the label
  :ghash.
  """
  def add(records, graph)

  def add(nil, graph), do: {:ok, graph}

  def add({structures, relations}, graph) do
    with :ok <- validate_graph(graph, structures) do
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
    else
      e -> e
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

  defp bottom_up(g) do
    g
    |> :digraph_utils.topsort()
    |> Enum.reverse()
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
      |> :digraph.out_neighbours(id)
      |> Enum.map(&:digraph.vertex(g, &1))

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
    |> Enum.map(& &1[:hash])
    |> Hasher.hash()
  end

  # Global hash is hash of parent record and all descendent records
  def global_hash([parent | children]) do
    {_, labels} = parent

    child_hashes =
      children
      |> Enum.map(fn {_, labels} -> labels end)
      |> Enum.map(&(&1[:ghash] || &1[:hash]))

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
    add_parent_child(graph, parent, child)
  end

  defp add_parent_child(_graph, id, id) do
    raise("reflexive relations are not permitted (#{id})")
  end

  defp add_parent_child(graph, parent, child) do
    :digraph.add_edge(graph, parent, child)
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
