defmodule TdDd.Loader do
  @moduledoc """
  Bulk loader for data structure metadata
  """

  import Ecto.Query, warn: false

  alias Ecto.Multi
  alias TdDd.DataStructures.RelationTypes
  alias TdDd.Loader.Context
  alias TdDd.Loader.FieldsAsStructures
  alias TdDd.Loader.LoadGraph
  alias TdDd.Loader.Metadata
  alias TdDd.Loader.Relations
  alias TdDd.Loader.Structures
  alias TdDd.Loader.Versions
  alias TdDd.Repo

  require Logger

  def load(records, audit, opts \\ [])

  def load(%{structures: structure_records, fields: field_records} = records, audit, opts) do
    structure_count = Enum.count(structure_records)
    field_count = Enum.count(field_records)
    Logger.info("Starting bulk load (#{structure_count}SR+#{field_count}FR)")

    {structure_records, relation_records} =
      FieldsAsStructures.fields_as_structures(
        structure_records,
        field_records,
        Map.get(records, :relations, [])
      )

    relation_records = RelationTypes.with_relation_types(relation_records)

    multi(structure_records, relation_records, audit, opts)
  end

  def load(%{structures: structure_records} = records, audit, opts) do
    structure_count = Enum.count(structure_records)
    Logger.info("Starting bulk load (#{structure_count}SR)")

    relation_records =
      records
      |> Map.get(:relations, [])
      |> RelationTypes.with_relation_types()

    multi(structure_records, relation_records, audit, opts)
  end

  @spec multi([map], [map], %{ts: DateTime.t()}, Keyword.t()) ::
          {:ok, map} | {:error, Multi.name(), any(), %{required(Multi.name()) => any()}}
  def multi(structure_records, relation_records, %{ts: ts} = audit, opts \\ []) do
    Multi.new()
    |> Multi.run(:graph, LoadGraph, :load_graph, [structure_records, relation_records, opts])
    |> Multi.run(:context, Context, :create_context, [audit])
    |> Multi.run(:delete_versions, Versions, :delete_missing_versions, [structure_records, ts])
    |> Multi.run(:insert_versions, Versions, :insert_new_versions, [ts])
    |> Multi.run(:restore_versions, Versions, :restore_deleted_versions, [])
    |> Multi.run(:update_versions, Versions, :update_existing_versions, [ts])
    |> Multi.run(:replace_versions, Versions, :replace_changed_versions, [ts])
    |> Multi.run(:insert_relations, Relations, :insert_new_relations, [ts])
    |> Multi.run(:update_domain_ids, Structures, :update_domain_ids, [structure_records, ts])
    |> Multi.run(:update_source_ids, Structures, :update_source_ids, [structure_records, opts[:source], ts])
    |> Multi.run(:delete_metadata, Metadata, :delete_missing_metadata, [ts])
    |> Multi.run(:replace_metadata, Metadata, :replace_metadata, [structure_records, ts])
    |> Multi.run(:structure_ids, __MODULE__, :structure_ids, [])
    |> Repo.transaction()
  end

  def structure_ids(_repo, %{} = changes) do
    structure_ids =
      changes
      |> Map.drop([:context, :graph, :insert_relations])
      |> Enum.flat_map(&structure_ids/1)
      |> Enum.uniq()

    {:ok, structure_ids}
  end

  defp structure_ids({:delete_versions, {_, ids}}), do: ids
  defp structure_ids({:restore_versions, {_, ids}}), do: ids
  defp structure_ids({:update_domain_ids, {_, ids}}), do: ids
  defp structure_ids({:update_source_ids, {_, ids}}), do: ids
  defp structure_ids({:delete_metadata, {_, ids}}), do: ids
  defp structure_ids({:replace_metadata, ids}), do: ids
  defp structure_ids({:insert_versions, {_, dsvs}}), do: Enum.map(dsvs, & &1.data_structure_id)
  defp structure_ids({:update_versions, {_, dsvs}}), do: Enum.map(dsvs, & &1.data_structure_id)
  defp structure_ids({:replace_versions, {_, dsvs}}), do: Enum.map(dsvs, & &1.data_structure_id)
end
