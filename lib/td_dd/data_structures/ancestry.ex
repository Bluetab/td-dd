defmodule TdDd.DataStructures.Ancestry do
  @moduledoc """
  This module is used by the bulk load process to obtain current (as-is)
  and new (to-be) ancestors of a data structure. The ancestors and their
  children are loaded into the bulk load graph (see `TdDd.DataStructures.Graph`)
  in order that their hashes can be recalculated.
  """

  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Repo

  @doc """
  Obtain structure and relation records for the current and future ancestors of a given
  external_id and parent_external_id.
  """
  def get_ancestor_records(external_id, parent_external_id)

  def get_ancestor_records(nil = _external_id, nil = _parent_external_id), do: nil

  def get_ancestor_records(external_id, nil) do
    external_id
    |> get_current_ancestor_relations([external_id])
    |> to_records
  end

  def get_ancestor_records(external_id, parent_external_id) do
    [
      get_current_ancestor_relations(external_id, [external_id]),
      get_new_ancestor_relations(parent_external_id, [external_id])
    ]
    |> Enum.concat()
    |> to_records(external_id, parent_external_id)
  end

  defp get_current_ancestor_relations(%DataStructureVersion{} = dsv, excludes) do
    ancestors =
      dsv
      |> DataStructures.get_ancestors()
      |> Repo.preload(:data_structure)
      |> Enum.map(&Map.put(&1, :rehash, true))

    ancestors
    |> Enum.map(&get_children(&1, excludes))
    |> Enum.zip(ancestors)
  end

  defp get_current_ancestor_relations(nil, _), do: []

  defp get_current_ancestor_relations(external_id, excludes) do
    external_id
    |> DataStructures.get_latest_version_by_external_id()
    |> get_current_ancestor_relations(excludes)
  end

  defp get_children(parent, excludes \\ [])

  defp get_children(parent, []) do
    DataStructures.get_children(parent, deleted: false)
  end

  defp get_children(parent, excludes) do
    parent
    |> get_children()
    |> Enum.reject(&Enum.member?(excludes, &1.data_structure.external_id))
  end

  defp get_new_ancestor_relations(parent_external_id, excludes) do
    parent =
      parent_external_id
      |> DataStructures.get_latest_version_by_external_id()
      |> Repo.preload(:data_structure)

    ancestors =
      [parent | DataStructures.get_ancestors(parent)]
      |> Repo.preload(:data_structure)

    ancestors |> Enum.map(&get_children(&1, excludes)) |> Enum.zip(ancestors)
  end

  defp to_records(children_with_ancestors, external_id \\ nil, parent_external_id \\ nil)

  defp to_records(children_with_ancestors, nil, nil) do
    relation_records =
      children_with_ancestors
      |> Enum.flat_map(&relation_records/1)
      |> Enum.uniq()

    structure_records =
      children_with_ancestors
      |> Enum.flat_map(fn {children, parent} -> [Map.put(parent, :rehash, true) | children] end)
      |> Enum.sort_by(&(not Map.has_key?(&1, :rehash)))
      |> Enum.uniq_by(& &1.data_structure_id)
      |> Enum.map(&structure_record/1)

    {structure_records, relation_records}
  end

  defp to_records(children_with_ancestors, external_id, parent_external_id) do
    {stuctures, relations} = to_records(children_with_ancestors)

    {
      stuctures,
      Enum.uniq([relation_record(parent_external_id, external_id) | relations])
    }
  end

  defp structure_record(%DataStructureVersion{data_structure: %{external_id: external_id}} = dsv) do
    {external_id, Map.drop(dsv, [:data_structure, :parents, :children])}
  end

  defp relation_records({children, parent}) do
    Enum.map(children, &relation_record(parent, &1))
  end

  defp relation_record(%DataStructureVersion{data_structure: parent}, %DataStructureVersion{
         data_structure: child
       }) do
    relation_record(parent, child)
  end

  defp relation_record(%DataStructure{external_id: parent_external_id}, %DataStructure{
         external_id: child_external_id
       }) do
    relation_record(parent_external_id, child_external_id)
  end

  defp relation_record(parent_external_id, child_external_id) do
    %{parent_external_id: parent_external_id, child_external_id: child_external_id}
  end
end
