defmodule TdDd.GraphDataCase do
  @moduledoc """
  Graph Data setup for tests.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias TdDd.Lineage.GraphData
      alias TdDd.Lineage.GraphData.State

      setup tags do
        start_supervised({GraphData, state: setup_state(tags)})
        :ok
      end

      defp setup_state(%{contains: contains, depends: depends} = _tags) do
        c = setup_graph(contains)

        d =
          Enum.reduce(depends, Graph.subgraph(c, Graph.sink_vertices(c)), fn
            {v1, v2, [metadata: metadata]}, g ->
              Graph.add_edge(g, v1, v2, %{:metadata => metadata})

            {v1, v2}, g ->
              Graph.add_edge(g, v1, v2)
          end)

        %State{contains: c, depends: d, roots: Graph.source_vertices(c)}
      end

      defp setup_state(_), do: nil

      defp setup_graph(nodes) do
        Enum.reduce(nodes, Graph.new(), &add_node/2)
      end

      defp add_node({parent, [_ | _] = children}, %Graph{} = g) do
        g = Graph.add_vertex(g, parent, label(parent, "Group"))
        g = Enum.reduce(children, g, &add_node/2)
        Enum.reduce(children, g, &Graph.add_edge(&2, parent, &1))
      end

      defp add_node(child, %Graph{} = g) do
        Graph.add_vertex(g, child, label(child))
      end

      defp label(external_id, class \\ "Resource", type \\ "foo_type") do
        %{
          :class => class,
          :external_id => external_id,
          "name" => external_id,
          "type" => type
        }
      end
    end
  end
end
