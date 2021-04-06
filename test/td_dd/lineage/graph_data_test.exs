defmodule TdDd.Lineage.GraphDataTest do
  use ExUnit.Case

  alias TdDd.Lineage.GraphData
  alias TdDd.Lineage.GraphData.State

  setup context do
    unless context[:disabled] do
      depends =
        [:foo, :bar]
        |> Graph.new()
        |> Graph.add_edge(:foo, :bar)

      start_supervised({GraphData, state: %State{depends: depends}})
    end

    :ok
  end

  describe "GraphData" do
    @tag :disabled
    test "degree/1 returns error if GraphData is down" do
      assert GraphData.degree(:foo) == {:error, :down}
    end

    test "degree/1 returns error if node does not exist" do
      assert GraphData.degree(:baz) == {:error, :bad_vertex}
    end

    test "degree/1 returns degree if node exists" do
      assert GraphData.degree(:foo) == {:ok, %{in: 0, out: 1}}
      assert GraphData.degree(:bar) == {:ok, %{in: 1, out: 0}}
    end
  end
end
