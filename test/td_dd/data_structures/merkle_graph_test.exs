defmodule TdDd.DataStructures.MerkleGraphTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias TdDd.DataStructures.MerkleGraph

  describe "TdDd.DataStructures.MerkleGraph" do
    test "new/2 generates a graph with vertices and edges" do
      external_ids = ["foo", "bar", "baz"]
      {structures, relations} = tree(external_ids)

      assert {:ok, graph} = MerkleGraph.new(structures, relations)
      assert Graph.no_vertices(graph) == 3
      assert Graph.no_edges(graph) == 2
      assert MapSet.new(Graph.vertices(graph)) == MapSet.new(external_ids)
    end

    test "new/2 does not allow cycles" do
      {structures, relations} = tree(["foo", "bar", "baz", "foo"])

      assert capture_log(fn ->
               {:error, "duplicate foo"} = MerkleGraph.new(structures, relations)
             end) =~ "duplicate foo"
    end
  end

  defp tree(external_ids) do
    structures = Enum.map(external_ids, &%{external_id: &1})

    relations =
      external_ids
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [parent, child] ->
        %{
          parent_external_id: parent,
          child_external_id: child,
          relation_type_id: 1,
          relation_type_name: "default"
        }
      end)

    {structures, relations}
  end
end
