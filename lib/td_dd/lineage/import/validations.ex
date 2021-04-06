defmodule TdDd.Lineage.Import.Validations do
  @moduledoc """
  Applies validations to Lineage import graphs.
  """

  defstruct [
    :invalid_node_class,
    :invalid_edge_class,
    :invalid_depends,
    :invalid_contains,
    :contained_by_many,
    :contained_by_none,
    valid: true
  ]

  @doc """
  Returns a map of non-nil validations.
  """
  def to_map(%__MODULE__{} = struct) do
    struct
    |> Map.from_struct()
    |> Map.delete(:valid)
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end

  @doc """
  Performs the following validations on a graph:
   - All vertices must have class "Resource" or "Group"
   - All edges must have class "CONTAINS" or "DEPENDS"
   - All "Resource" vertices must be contained by exactly one Group
   - All "Group" vertices must be contained by one or zero Groups
   - All "Depends" edges are between two Resources
  """
  def validate(%Graph{} = graph) do
    vertices_by_class =
      graph
      |> Graph.vertices(labels: true)
      |> Enum.group_by(fn {_id, label} -> Map.get(label, :class) end, fn {id, _label} -> id end)
      |> Map.put_new("Group", [])
      |> Map.put_new("Resource", [])
      |> Map.new(fn {class, ids} -> {class, MapSet.new(ids)} end)

    edges_by_class =
      graph
      |> Graph.get_edges(fn {_id, {v1, v2, label}} -> %{v1: v1, v2: v2, label: label} end)
      |> Enum.group_by(fn %{label: label} -> Map.get(label, :class) end, fn edge ->
        Map.delete(edge, :label)
      end)
      |> Map.put_new("CONTAINS", [])
      |> Map.put_new("DEPENDS", [])

    %__MODULE__{}
    |> validate_empty(:invalid_node_class, invalid_node_class(vertices_by_class))
    |> validate_empty(:invalid_edge_class, invalid_edge_class(edges_by_class))
    |> validate_empty(:invalid_depends, validate_depends(edges_by_class, vertices_by_class))
    |> validate_contains(edges_by_class, vertices_by_class)
  end

  defp invalid_node_class(vertices_by_class) do
    vertices_by_class
    |> Map.drop(["Group", "Resource"])
    |> Map.keys()
  end

  defp invalid_edge_class(edges_by_class) do
    edges_by_class
    |> Map.drop(["CONTAINS", "DEPENDS"])
    |> Map.keys()
  end

  defp validate_depends(%{"DEPENDS" => depends}, %{"Resource" => resources}) do
    Enum.reject(depends, fn %{v1: v1, v2: v2} ->
      MapSet.member?(resources, v1) and MapSet.member?(resources, v2)
    end)
  end

  defp validate_contains(
         %{} = errors,
         %{"CONTAINS" => contains},
         %{"Group" => groups, "Resource" => resources}
       ) do
    {valid_contains, invalid_contains} =
      Enum.split_with(contains, fn %{v1: v1} -> MapSet.member?(groups, v1) end)

    contained_by = Enum.group_by(valid_contains, fn %{v2: v2} -> v2 end, fn %{v1: v1} -> v1 end)

    contained =
      contained_by
      |> Map.keys()
      |> MapSet.new()

    contained_by_many =
      contained_by
      |> Enum.reject(fn {_child, parents} -> length(parents) == 1 end)
      |> Enum.map(fn {child, _parents} -> child end)

    contained_by_none =
      resources
      |> MapSet.difference(contained)
      |> MapSet.to_list()

    errors
    |> validate_empty(:invalid_contains, invalid_contains)
    |> validate_empty(:contained_by_many, contained_by_many)
    |> validate_empty(:contained_by_none, contained_by_none)
  end

  defp validate_empty(%__MODULE__{} = errors, _key, []), do: errors

  defp validate_empty(%__MODULE__{} = errors, key, value) do
    %{errors | :valid => false, key => value}
  end
end
