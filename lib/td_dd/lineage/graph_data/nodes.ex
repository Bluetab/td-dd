defmodule TdDd.Lineage.GraphData.Nodes do
  @moduledoc """
  Functions for handling graph data node queries.
  """
  alias Graph.Traversal
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Lineage.GraphData.State
  alias TdDd.Lineage.Units
  alias TdDd.Lineage.Units.Node

  @doc """
  Returns the context of a given external id within hierarchy graph. The context
  consists of a list of parent nodes with the siblings of the selected child.
  """
  def query_nodes(external_id, user, %State{contains: t, roots: roots}) do
    case path(t, external_id) do
      :not_found ->
        {:error, :not_found}

      path ->
        res =
          [nil | path]
          |> Enum.map(&{&1, children(t, &1, roots, user)})
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

  defp children(%Graph{} = t, id, roots, user) do
    t
    |> do_children(id, roots)
    |> Enum.reject(&by_permissions(user, t, &1))
    |> Enum.reject(&hidden?(t, &1))
    |> Enum.map(&Graph.vertex(t, &1))
    |> Enum.map(&node_label/1)
    |> Enum.sort_by(&sortable/1)
    |> Enum.group_by(&class/1, &Map.delete(&1, :class))
  end

  defp do_children(%Graph{} = _t, nil, roots), do: roots
  defp do_children(%Graph{} = t, id, _roots), do: Graph.out_neighbours(t, id)

  defp hidden?(%Graph{} = t, id) do
    Graph.vertex(t, id, "hidden") == true
  end

  defp by_permissions(user, t, node) do
    item = Units.get_node(node, preload: [:structure])

    case has_permissions?(user, item) do
      true ->
        [node]
        |> Traversal.reachable(t)
        |> Enum.map(&Graph.vertex(t, &1))
        |> Enum.map(&Map.get(&1, :id))
        |> List.delete(node) 
        |> reject?(user)

      false -> true
    end
  end

  defp has_permissions?(user, %Node{structure: %DataStructure{} = data_structure}) do
    import Canada, only: [can?: 2]
    can?(user, view_data_structure(data_structure))
  end

  defp has_permissions?(_user, _node), do: true

  defp reject?([], _user), do: false

  defp reject?(ids, user) do
    nodes =
      Map.new()
      |> Map.put(:external_id, ids)
      |> Units.list_nodes(preload: [:structure])

    groups = Enum.filter(nodes, &(Map.get(&1, :type) == "Group"))
    resources = Enum.filter(nodes, &(Map.get(&1, :type) == "Resource"))

    case reject_collection?(resources, user) do
      false -> reject_collection?(groups, user)
      _ -> true
    end
  end

  defp reject_collection?([], _user), do: false

  defp reject_collection?(collection, user) do
    not Enum.any?(collection, &has_permissions?(user, &1))
  end

  defp class(%{class: "Group"}), do: :groups
  defp class(%{class: "Resource"}), do: :resources

  defp node_label(%{label: label, id: id}) do
    label
    |> Map.take(["name", "type", :class])
    |> Map.put("external_id", id)
  end

  defp node_label(_), do: %{}

  defp sortable(%{"name" => name}), do: String.downcase(name)
  defp sortable(thing), do: thing
end
