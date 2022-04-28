defmodule TdDd.Lineage.Import.ValidationsTest do
  use ExUnit.Case

  alias TdDd.Lineage.Import.Validations

  describe "TdDd.Lineage.Import.Validations" do
    test "has valid true if graph is valid" do
      graph =
        Graph.new()
        |> Graph.add_vertex("Group1", class: "Group")
        |> Graph.add_vertex("Resource1", class: "Resource")
        |> Graph.add_vertex("Resource2", class: "Resource")
        |> Graph.add_edge("Group1", "Resource1", class: "CONTAINS", metada: %{})
        |> Graph.add_edge("Group1", "Resource2", class: "CONTAINS", metada: %{})
        |> Graph.add_edge("Resource1", "Resource2", class: "DEPENDS", metada: %{})

      assert %Validations{valid: true} = Validations.validate(graph)
    end

    test "identifies invalid node and edge classes" do
      graph =
        Graph.new()
        |> Graph.add_vertex(:v1, class: "FOO")
        |> Graph.add_vertex(:v2, class: "BAR")
        |> Graph.add_edge(:v1, :v2, class: "BAZ", metada: %{})
        |> Graph.add_edge(:v2, :v1, class: "XYZZY", metada: %{})

      assert %Validations{
               valid: false,
               invalid_node_class: ["BAR", "FOO"],
               invalid_edge_class: ["BAZ", "XYZZY"]
             } = Validations.validate(graph)
    end

    test "identifies resources not contained by no groups or multiple groups" do
      graph =
        Graph.new()
        |> Graph.add_vertex("Group1", class: "Group")
        |> Graph.add_vertex("Group2", class: "Group")
        |> Graph.add_vertex("Resource1", class: "Resource")
        |> Graph.add_vertex("Resource2", class: "Resource")
        |> Graph.add_edge("Group1", "Resource1", class: "CONTAINS", metada: %{})
        |> Graph.add_edge("Group2", "Resource1", class: "CONTAINS", metada: %{})

      assert %Validations{
               valid: false,
               contained_by_many: ["Resource1"],
               contained_by_none: ["Resource2"]
             } = Validations.validate(graph)
    end

    test "identifies invalid CONTAINS and DEPENDS relations" do
      graph =
        Graph.new()
        |> Graph.add_vertex("Group", class: "Group")
        |> Graph.add_vertex("Resource1", class: "Resource")
        |> Graph.add_vertex("Resource2", class: "Resource")
        |> Graph.add_edge("Group", "Resource1", class: "DEPENDS", metada: %{})
        |> Graph.add_edge("Resource2", "Resource1", class: "CONTAINS", metada: %{})

      assert %Validations{
               valid: false,
               invalid_contains: [%{v1: "Resource2", v2: "Resource1"}],
               invalid_depends: [%{v1: "Group", v2: "Resource1"}]
             } = Validations.validate(graph)
    end
  end
end
