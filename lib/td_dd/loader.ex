defmodule TdDd.Loader do
  @moduledoc """
  Bulk loader for data structure metadata
  """

  alias Ecto.Multi
  alias TdDd.Classifiers
  alias TdDd.DataStructures.Hierarchy
  alias TdDd.DataStructures.RelationTypes
  alias TdDd.Loader.Context
  alias TdDd.Loader.FieldsAsStructures
  alias TdDd.Loader.LoadGraph
  alias TdDd.Loader.Metadata
  alias TdDd.Loader.Relations
  alias TdDd.Loader.Structures
  alias TdDd.Loader.Types
  alias TdDd.Loader.Versions
  alias TdDd.Repo

  require Logger

  @typep multi_error :: {:error, Multi.name(), any(), %{required(Multi.name()) => any()}}
  @typep multi_success :: {:ok, map()}
  @typep multi_result :: multi_success() | multi_error()

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

    multi(
      structure_records,
      relation_records,
      audit,
      opts
    )
  end

  @spec replace_mutable_metadata([map], TdDd.Systems.System.t(), map, Keyword.t()) ::
          multi_result()
  def replace_mutable_metadata(records, system, audit, opts) do
    count = Enum.count(records)
    Logger.info("Starting mutable metadata bulk replace (#{count} records)")
    metadata_multi(records, system, audit, opts[:operation])
  end

  @spec multi([map], [map], %{ts: DateTime.t()}, Keyword.t()) :: multi_result()
  def multi(structure_records, relation_records, %{ts: ts} = audit, opts \\ []) do
    Multi.new()
    |> Multi.run(:graph, LoadGraph, :load_graph, [structure_records, relation_records, opts])
    |> Multi.run(:context, Context, :create_context, [audit])
    |> Multi.run(:insert_types, Types, :insert_missing_types, [structure_records, ts])
    |> Multi.run(:delete_versions, Versions, :delete_missing_versions, [structure_records, ts])
    |> Multi.run(:insert_versions, Versions, :insert_new_versions, [ts])
    |> Multi.run(:restore_versions, Versions, :restore_deleted_versions, [])
    |> Multi.run(:update_versions, Versions, :update_existing_versions, [ts])
    |> Multi.run(:replace_versions, Versions, :replace_changed_versions, [ts])
    |> Multi.run(:insert_relations, Relations, :insert_new_relations, [ts])
    |> Multi.run(:update_hierarchy, Hierarchy, :update_hierarchy, [])
    |> Multi.run(:update_domain_ids, Structures, :update_domain_ids, [structure_records, ts])
    |> Multi.run(:maybe_inherit_domains, __MODULE__, :maybe_inherit_domains, [ts, opts])
    |> Multi.run(:update_source_ids, Structures, :update_source_ids, [
      structure_records,
      opts[:source],
      ts
    ])
    |> replace_or_merge_metadata(structure_records, ts, opts[:operation])
    |> Multi.run(:structure_ids, __MODULE__, :structure_ids, [])
    |> Multi.run(:system_ids, fn _, _ -> {:ok, system_ids(structure_records)} end)
    |> Multi.run(:classification, fn _, %{system_ids: ids} ->
      Classifiers.classify_many(ids, updated_at: ts)
    end)
    |> Multi.run(:refresh_fields, Types, :refresh_fields, [])
    |> Repo.transaction()
  end

  def maybe_inherit_domains(_repo, changes, ts, opts) do
    case {changes, Keyword.get(opts, :inherit_domains)} do
      {%{insert_versions: {_, dsvs}}, true} ->
        Structures.inherit_domain(dsvs, ts)

      _ ->
        {:ok, {0, []}}
    end
  end

  @spec metadata_multi([map], TdDd.Systems.System.t(), map, binary()) :: multi_result()
  def metadata_multi(records, system, %{ts: ts} = _audit, operation \\ "replace") do
    Multi.new()
    |> Multi.run(:missing_external_ids, Metadata, :missing_external_ids, [records, system])
    |> replace_or_merge_metadata(records, ts, operation)
    |> Multi.run(:structure_ids, __MODULE__, :structure_ids, [])
    |> Repo.transaction()
  end

  defp replace_or_merge_metadata(multi, structure_records, ts, "merge") do
    Multi.run(multi, :merge_metadata, Metadata, :merge_metadata, [structure_records, ts])
  end

  defp replace_or_merge_metadata(multi, structure_records, ts, _replace) do
    multi
    |> Multi.run(:delete_metadata, Metadata, :delete_missing_metadata, [ts])
    |> Multi.run(:replace_metadata, Metadata, :replace_metadata, [structure_records, ts])
  end

  def system_ids(structure_records) do
    structure_records
    |> MapSet.new(& &1.system_id)
    |> MapSet.to_list()
  end

  def structure_ids(_repo, %{} = changes) do
    structure_ids =
      changes
      |> Map.drop([:context, :graph, :insert_relations, :update_hierarchy, :maybe_inherit_domains])
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
  defp structure_ids({:merge_metadata, ids}), do: ids
  defp structure_ids({:insert_versions, {_, dsvs}}), do: Enum.map(dsvs, & &1.data_structure_id)
  defp structure_ids({:update_versions, {_, dsvs}}), do: Enum.map(dsvs, & &1.data_structure_id)
  defp structure_ids({:replace_versions, {_, dsvs}}), do: Enum.map(dsvs, & &1.data_structure_id)
  defp structure_ids({:missing_external_ids, _}), do: []
  defp structure_ids({:insert_types, _}), do: []
end
