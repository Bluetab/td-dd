defmodule TdDd.DataStructures.Ancestry do
  @moduledoc """
  This module is used by the bulk load process to obtain current (as-is) and new
  (to-be) ancestors of a data structure. The ancestors and their children are
  loaded into the bulk load graph (see `TdDd.DataStructures.MerkleGraph`) in
  order that their hashes can be recalculated.
  """

  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Repo

  @doc """
  For a given external_id, obtain the id of the corresponding data structure
  and all it's descendents. Used to reindex a data structure and it's descendents
  when it's route has been affected by a bulk upload process.
  """
  def get_descendent_ids(external_id) do
    dsv = DataStructures.get_latest_version_by_external_id(external_id)

    [dsv | DataStructures.get_descendents(dsv)]
    |> Enum.map(& &1.data_structure_id)
  end

  @doc """
  Obtain structure and relation records for the current and future ancestors of a given
  external_id and parent_external_id.
  """
  def get_ancestor_records(external_id, parent_external_id)

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
    |> Enum.uniq_by(fn {_, ancestor} -> ancestor.data_structure_id end)
    |> to_records(external_id, parent_external_id)
  end

  defp get_current_ancestor_relations(%DataStructureVersion{} = dsv, excludes) do
    ancestors =
      dsv
      |> DataStructures.get_ancestors()
      |> Repo.preload(:data_structure)
      |> Enum.map(fn %{data_structure: %{external_id: external_id}} = dsv ->
        %{dsv | external_id: external_id}
      end)

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
    parent
    |> DataStructures.get_children(deleted: false)
    |> Enum.map(fn %{data_structure: %{external_id: external_id}} = dsv ->
      %{dsv | external_id: external_id}
    end)
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

    parents =
      children_with_ancestors
      |> Enum.map(fn {_, parent} -> Map.drop(parent, [:lhash, :ghash]) end)

    parent_data_structure_ids = Enum.map(parents, & &1.data_structure_id)

    children =
      children_with_ancestors
      |> Enum.flat_map(fn {children, _} -> children end)
      |> Enum.reject(&Enum.member?(parent_data_structure_ids, &1.data_structure_id))

    structure_records =
      [parents, children]
      |> Enum.concat()
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
