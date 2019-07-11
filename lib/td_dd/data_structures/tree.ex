defmodule TdDd.DataStructures.Tree do

  def new(structures, fields, relations) do
    graph = structures
    |> Enum.reduce(:digraph.new([:acyclic]), &add_structure/2)

    graph = fields
    |> Enum.reduce(graph, &add_field/2)

    graph = relations
    |> Enum.reduce(graph, &add_relation/2)

    trees = graph
    |> :digraph_utils.components
    |> Enum.map(& :digraph_utils.subgraph(graph, &1))
    |> Enum.map(&propagate_hashes/1)

    :digraph.delete(graph)

    trees
  end

  defp propagate_hashes(g) do
    # Calculate hashes from bottom up
    g
    |> :digraph_utils.topsort()
    |> Enum.reject(& elem(&1, 0) == :field)
    |> Enum.reverse()
    |> Enum.each(& propagate_hashes(&1, g))

    g
  end

  def propagate_hashes(id, g) do
    parent = :digraph.vertex(g, id)

    children = :digraph.out_neighbours(g, id)
    |> Enum.map(& :digraph.vertex(g, &1))

    lhash = local_hash([parent | children])
    ghash = global_hash([parent | children])

    {^id, labels} = parent

    labels = labels
    |> Keyword.put(:lhash, lhash)
    |> Keyword.put(:ghash, ghash)

    :digraph.add_vertex(g, id, labels)
  end

  # Local hash is hash of parent record and immediate child records
  def local_hash(vertices) do
    vertices
    |> Enum.map(fn {_, labels} -> labels end)
    |> Enum.map(& &1[:hash])
    |> hash()
  end

  def global_hash([{_, labels}]) do
    labels[:hash]
  end

  # Global hash is hash of parent record and all descendent records
  def global_hash([parent | children]) do
    {_, labels} = parent

    child_hashes = children
    |> Enum.map(fn {_, labels} -> labels end)
    |> Enum.map(& &1[:ghash] || &1[:hash])

    [labels[:hash] | child_hashes]
    |> hash()
  end

  defp add_structure(structure, graph) do
    hash = hash(structure)

    structure
    |> get_id()
    |> add_vertex(graph, [record: structure, hash: hash])

    graph
  end

  defp add_field(field, graph) do
    hash = hash(field)

    parent = structure_vertex(field, graph)

    child = field
    |> get_id()
    |> add_vertex(graph, [record: field, hash: hash])

    add_parent_child(graph, parent, child)
  end

  defp add_relation(relation, graph) do
    parent = parent_vertex(relation, graph)
    child = child_vertex(relation, graph)
    add_parent_child(graph, parent, child)
  end

  defp add_parent_child(graph, parent, child) do
    :digraph.add_edge(graph, parent, child)
    graph
  end

  defp structure_vertex(rec, graph) do
    id = rec
    |> Map.take([:system_id, :external_id])
    |> get_id()

    {v, _} = :digraph.vertex(graph, id)
    v
  end

  defp parent_vertex(%{system_id: system_id, parent_external_id: external_id}, graph) do
    %{system_id: system_id, external_id: external_id}
    |> structure_vertex(graph)
  end

  defp child_vertex(%{system_id: system_id, child_external_id: external_id}, graph) do
    %{system_id: system_id, external_id: external_id}
    |> structure_vertex(graph)
  end

  defp add_vertex(id, graph, labels) do
    case :digraph.vertex(graph, id) do
      false -> :digraph.add_vertex(graph, id, labels)
      _ -> raise("duplicate")
    end
  end

  defp get_id(%{system_id: system_id, parent_external_id: parent_external_id, child_external_id: child_external_id}) do
    {:relation, system_id, parent_external_id, child_external_id}
  end

  defp get_id(%{external_id: external_id, system_id: system_id, field_name: field_name}) do
    {:field, system_id, external_id, field_name}
  end

  defp get_id(%{external_id: external_id, system_id: system_id}) do
    {:structure, system_id, external_id}
  end

  defp hash(record) when is_map(record) do
    record
    |> Jason.encode!()
    |> hash()
  end

  defp hash(list) when is_list(list) do
    list
    |> Enum.join()
    |> hash()
  end

  defp hash(binary) when is_binary(binary) do
    :crypto.hash(:blake2b, binary)
  end
end