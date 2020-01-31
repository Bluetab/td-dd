defmodule TdDd.Lineage.GraphData.Nodes do
  @moduledoc """
  Functions for handling graph data node queries.
  """
  alias Graph.Traversal
  alias TdDd.Lineage.GraphData.State

  @doc """
  Returns the context of a given external id within hierarchy graph. The context
  consists of a list of parent nodes with the siblings of the selected child.
  """
  def query_nodes(external_id, %State{contains: t, roots: roots}) do
    case path(t, external_id) do
      :not_found ->
        {:error, :not_found}

      path ->
        res =
          [nil | path]
          |> Enum.map(&{&1, children(t, &1, roots)})
          |> Enum.map(fn {parent, m} -> Map.put(m, :parent, parent) end)

        {:ok, res}
    end
  end

  defp path(%Graph{} = _t, nil), do: []

  defp path(%Graph{} = t, id) do
    if Graph.has_vertex?(t, id) do
      t
      |> Traversal.reaching_subgraph([id])
      |> Traversal.topsort()
    else
      :not_found
    end
  end

  defp children(%Graph{} = t, id, roots) do
    t
    |> do_children(id, roots)
    |> Enum.filter(&visible?(t, &1))
    |> Enum.map(&Graph.vertex(t, &1, :data))
    |> Enum.map(&node_label/1)
    |> Enum.sort_by(&sortable/1)
    |> Enum.group_by(&class/1, &Map.delete(&1, :class))
  end

  defp do_children(%Graph{} = _t, nil, roots), do: roots
  defp do_children(%Graph{} = t, id, _roots), do: Graph.out_neighbours(t, id)

  defp visible?(%Graph{} = t, id) do
    case Graph.vertex(t, id, :data) do
      %{properties: %{"select_hidden" => true}} -> false
      _ -> true
    end
  end

  defp class(%{class: "Group"}), do: :groups
  defp class(%{class: "Resource"}), do: :resources

  defp node_label(%{data: data}), do: node_label(data)

  defp node_label(%{properties: properties, labels: [class], id: id}) do
    properties
    |> Map.take(["name", "external_id", "type"])
    |> Map.put(:class, class)
    |> Map.put(:id, id)
  end

  defp node_label(_), do: %{}

  defp sortable(%{"name" => name}), do: String.downcase(name)
  defp sortable(thing), do: thing
end
