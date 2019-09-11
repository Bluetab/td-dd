defmodule TdDd.DataStructures.Graph do
  @moduledoc """
  This module transforms data structure bulk load records into a directed acyclic graph,
  and propagates the hashes of each node from the bottom up.
  """

  alias TdDd.DataStructures.Hasher

  def new(structures, relations) do
    graph =
      structures
      |> Enum.reduce(:digraph.new([:acyclic]), &add_structure/2)

    graph =
      relations
      |> Enum.reduce(graph, &add_relation/2)

    propagate_hashes(graph)
  end

  defp propagate_hashes(g) do
    # Calculate hashes from bottom up
    g
    |> :digraph_utils.topsort()
    |> Enum.reverse()
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

  defp add_structure(structure, graph) do
    hash = Hasher.hash(structure)

    structure
    |> get_id()
    |> add_vertex(graph, record: structure, hash: hash)

    graph
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
      false -> :digraph.add_vertex(graph, id, labels)
      _ -> raise("duplicate")
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
