defmodule TdDd.Lineage.GraphData.Nodes do
  @moduledoc """
  Functions for handling graph data node queries.
  """
  alias Graph.Traversal
  alias TdCache.TaxonomyCache
  alias TdDd.Lineage.GraphData.State
  alias TdDd.Lineage.NodeQuery
  alias TdDd.Lineage.Units

  @doc """
  Returns the context of a given external id within hierarchy graph. The context
  consists of a list of parent nodes with the siblings of the selected child.
  """
  def query_nodes(external_id, opts, claims, %State{contains: t, roots: roots}) do
    nodes_domain_ids = NodeQuery.nodes_domain_ids()

    case path(t, external_id) do
      :not_found ->
        {:error, :not_found}

      path ->
        res =
          [nil | path]
          |> Enum.map(&{&1, children(t, &1, roots, nodes_domain_ids, opts, claims)})
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

  defp children(%Graph{} = t, id, roots, nodes_domain_ids, opts, claims) do
    t
    |> do_children(id, roots)
    |> Enum.reject(&hidden?(t, &1))
    |> get_nodes(claims, nodes_domain_ids, opts[:domain_id])
    |> Enum.map(& &1.external_id)
    |> Enum.map(&Graph.vertex(t, &1))
    |> Enum.map(&node_label/1)
    |> Enum.sort_by(&sortable/1)
    |> Enum.group_by(&class/1, &Map.delete(&1, :class))
  end

  defp do_children(%Graph{} = _t, nil, roots), do: roots
  defp do_children(%Graph{} = t, id, _roots), do: Graph.out_neighbours(t, id)

  defp get_nodes(children, claims, nodes_domain_ids, nil) do
    %{external_id: children}
    |> Units.list_nodes(preload: :units)
    |> Enum.map(&domain_ids/1)
    |> Enum.map(&node_domain_ids(&1, nodes_domain_ids))
    |> Enum.filter(&Bodyguard.permit?(Units, :view_lineage, claims, &1))
  end

  defp get_nodes(children, claims, nodes_domain_ids, domain_id) do
    %{external_id: children}
    |> Units.list_nodes(preload: :units)
    |> Enum.map(&domain_ids/1)
    |> Enum.map(&node_domain_ids(&1, nodes_domain_ids))
    |> Enum.map(&parent_domain_ids/1)
    |> Enum.filter(fn %{parent_ids: parent_ids} -> domain_id in parent_ids end)
    # credo:disable-for-next-line
    |> Enum.filter(&Bodyguard.permit?(Units, :view_lineage, claims, &1))
  end

  defp node_domain_ids(%{id: id, domain_ids: domain_ids} = node, nodes_domain_ids) do
    nodes_domain_ids
    |> Enum.find(fn %{child_id: child_id} ->
      id == child_id
    end)
    |> case do
      nil ->
        node

      %{domain_ids: node_domain_ids} ->
        Map.put(node, :domain_ids, Enum.uniq(domain_ids ++ node_domain_ids))
    end
  end

  defp hidden?(%Graph{} = t, id) do
    Graph.vertex(t, id, "hidden") == true
  end

  defp domain_ids(%{units: units} = node) do
    domain_ids =
      units
      |> Enum.map(& &1.domain_id)
      |> Enum.filter(& &1)
      |> Enum.uniq()

    Map.put(node, :domain_ids, domain_ids)
  end

  defp parent_domain_ids(%{domain_ids: domain_ids} = node) do
    parent_ids = TaxonomyCache.reaching_domain_ids(domain_ids)
    Map.put(node, :parent_ids, parent_ids)
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
