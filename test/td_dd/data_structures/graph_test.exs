defmodule TdDd.DataStructures.GraphTest do
  use ExUnit.Case, async: true

  alias TdDd.DataStructures.Graph

  describe "TdDd.DataStructures.Graph" do
    test "new/2 generates a graph with vertices and edges" do
      external_ids = ["foo", "bar", "baz"]
      {structures, relations} = tree(external_ids)

      assert {:ok, graph} = Graph.add(Graph.new(), structures, relations)
      assert :digraph.no_vertices(graph) == 3
      assert :digraph.no_edges(graph) == 2
      assert MapSet.new(:digraph.vertices(graph)) == MapSet.new(external_ids)
    end

    test "new/2 does not allow cycles" do
      {structures, relations} = tree(["foo", "bar", "baz", "foo"])

      assert_raise(RuntimeError, fn -> Graph.add(Graph.new(), structures, relations) end)
    end
  end

  defp tree(external_ids) do
    structures =
      external_ids
      |> Enum.map(&%{external_id: &1})

    relations =
      external_ids
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [parent, child] ->
        %{parent_external_id: parent, child_external_id: child, relation_type_id: 1, relation_type_name: "default"}
      end)

    {structures, relations}
  end
end
