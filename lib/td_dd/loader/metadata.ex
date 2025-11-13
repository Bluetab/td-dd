defmodule TdDd.Loader.Metadata do
  @moduledoc """
  Bulk loader support for updating mutable metadata.
  """
  import Ecto.Query

  alias Ecto.Multi
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.StructureMetadata
  alias TdDd.Repo
  alias TdDd.Systems.System

  require Logger

  @type metadata_record :: %{external_id: binary(), mutable_metadata: map()}

  @chunk_size 1_000
  @unnest_external_ids "select external_id from unnest(?::text[]) t (external_id)"
  @unnest_records "select * from unnest(?::jsonb[]) t (data)"
  @expand_metadata "select data->>'external_id' as external_id, data->'mutable_metadata' as fields from data"

  @doc """
  Identifies external_ids which do not exist in the specified system
  """
  @spec missing_external_ids(atom, map, [metadata_record], System.t()) ::
          {:error, [integer()]} | {:ok, []}
  def missing_external_ids(_repo, _changes, records, %{id: system_id} = _system) do
    case missing_external_ids(records, system_id) do
      [] -> {:ok, []}
      [_ | _] = ids -> {:error, ids}
    end
  end

  @spec missing_external_ids([metadata_record], integer()) :: [integer()]
  def missing_external_ids(records, system_id) do
    records
    |> Enum.map(& &1.external_id)
    |> Enum.uniq()
    |> Enum.chunk_every(@chunk_size)
    |> Enum.flat_map(&select_missing_external_ids(system_id, &1))
  end

  @doc """
  Logically delete metadata versions whose external_id is absent from the
  structure records, but whose group is present.
  """
  def delete_missing_metadata(_repo, %{delete_versions: {_, [_ | _] = ids}}, ts) do
    {:ok, delete_metadata_versions(ids, ts)}
  end

  def delete_missing_metadata(_repo, _changes, _ts), do: {:ok, {0, []}}

  @spec replace_metadata(atom, map, [map], DateTime.t()) :: {:error, any} | {:ok, [integer()]}
  def replace_metadata(_repo, %{} = _changes, records, ts), do: replace_metadata(records, ts)

  @spec replace_metadata([map], DateTime.t()) :: {:error, any} | {:ok, [integer()]}
  def replace_metadata([], _), do: {:ok, []}

  def replace_metadata([_ | _] = records, ts) do
    records
    |> Map.new(&mutable_metadata_entry/1)
    |> do_update(ts)
  end

  @spec merge_metadata(atom, map, [map], DateTime.t()) :: {:error, any} | {:ok, [integer()]}
  def merge_metadata(_repo, %{} = _changes, records, ts), do: merge_metadata(records, ts)

  @spec merge_metadata([map], DateTime.t()) :: {:error, any} | {:ok, [integer()]}
  def merge_metadata([], _), do: {:ok, []}

  def merge_metadata([_ | _] = records, ts) do
    records
    |> Enum.map(&cast_merge/1)
    |> Enum.flat_map(fn
      {:ok, res} -> [res]
      {:error, _} -> []
    end)
    |> merge_existing_fields()
    |> do_update(ts)
  end

  def cast_merge(%{} = params) do
    import Ecto.Changeset

    {%{}, %{external_id: :string, mutable_metadata: :map}}
    |> cast(params, [:external_id, :mutable_metadata], empty_values: ["", %{}])
    |> validate_required([:external_id, :mutable_metadata])
    |> apply_action(:update)
  end

  defp mutable_metadata_entry(%{external_id: external_id, mutable_metadata: %{} = mm})
       when mm != %{} do
    {external_id, mm}
  end

  defp mutable_metadata_entry(%{external_id: external_id}) do
    {external_id, nil}
  end

  defp do_update(%{} = entries, _ts) when entries == %{}, do: {:ok, []}

  defp do_update(%{} = entries_by_external_id, ts) do
    entries_by_external_id
    |> Enum.chunk_every(@chunk_size)
    |> Enum.with_index()
    |> Enum.reduce(Multi.new(), &bulk_operations(&1, &2, ts))
    |> Repo.transaction()
    |> transform_result()
  end

  def merge_existing_fields(entries) do
    entries
    |> Enum.chunk_every(@chunk_size)
    |> Enum.flat_map(&do_merge_existing_fields/1)
    |> Map.new()
  end

  def do_merge_existing_fields(entries) do
    "fields_to_merge"
    |> with_cte("data", as: fragment(@unnest_records, ^entries))
    |> with_cte("fields_to_merge", as: fragment(@expand_metadata))
    |> join(:left, [rec], ds in DataStructure, on: ds.external_id == rec.external_id)
    |> join(:left, [_rec, ds], sm in assoc(ds, :metadata_versions))
    |> where([_rec, _ds, sm], is_nil(sm.deleted_at))
    |> select([rec, _, sm], %{
      external_id: rec.external_id,
      existing_metadata: sm.fields,
      merged_metadata: fragment("coalesce(?, '{}'::jsonb) || ?", sm.fields, rec.fields)
    })
    |> subquery()
    |> where([e], is_nil(e.existing_metadata) or e.merged_metadata != e.existing_metadata)
    |> select([e], {e.external_id, e.merged_metadata})
    |> Repo.all()
  end

  defp transform_result({:error, failed_operation, _failed_value, _changes_so_far}) do
    {:error, failed_operation}
  end

  defp transform_result({:ok, %{} = results}) do
    structure_ids =
      results
      |> Enum.flat_map(fn
        {{:updated, _chunk_id}, {_count, structure_ids}} ->
          structure_ids

        {{:inserted, _chunk_id}, {_count, metadata_version}} ->
          Enum.map(metadata_version, & &1.data_structure_id)
      end)

    {:ok, Enum.uniq(structure_ids)}
  end

  defp bulk_operations({chunk, chunk_id}, multi, ts) do
    external_ids = Enum.map(chunk, &elem(&1, 0))

    metadata_by_external_id =
      external_ids
      |> DataStructures.get_latest_metadata_by_external_ids()
      |> Map.new(&{&1.external_id, &1})

    structure_ids =
      external_ids
      |> get_structure_ids_by_external_ids()
      |> Enum.uniq()

    max_versions_by_structure_id =
      structure_ids
      |> get_max_metadata_versions()
      |> Map.new()

    chunk
    |> Enum.flat_map(fn {external_id, entry} ->
      metadata_result = Map.get(metadata_by_external_id, external_id)
      structure_id = if metadata_result, do: metadata_result.id, else: nil

      max_version =
        if structure_id, do: Map.get(max_versions_by_structure_id, structure_id, 0), else: 0

      operations(metadata_result, entry, max_version, ts)
    end)
    |> Enum.group_by(& &1.operation, &Map.delete(&1, :operation))
    |> Enum.reduce(multi, &reduce_multi(&1, &2, chunk_id, ts))
  end

  defp get_structure_ids_by_external_ids(external_ids) do
    DataStructure
    |> where([ds], ds.external_id in ^external_ids)
    |> select([ds], ds.id)
    |> Repo.all()
  end

  defp reduce_multi({:logical_delete, ops}, multi, chunk_id, ts) do
    ids = Enum.map(ops, & &1.id)

    queryable =
      StructureMetadata
      |> where([m], m.id in ^ids)
      |> select([m], m.data_structure_id)

    Multi.update_all(multi, {:updated, chunk_id}, queryable, set: [deleted_at: ts])
  end

  defp reduce_multi({:insert, entries}, multi, chunk_id, _ts) do
    Multi.insert_all(multi, {:inserted, chunk_id}, StructureMetadata, entries,
      returning: [:data_structure_id]
    )
  end

  # Handle case when DataStructure doesn't exist
  defp operations(nil, _entry, _max_version, _), do: []

  # Do nothing if current and new metadata are nil
  defp operations(%{latest_metadata: nil}, nil, _max_version, _), do: []

  # Do nothing if current metadata is deleted and new metadata is nil
  defp operations(%{latest_metadata: %{deleted_at: deleted_at}}, nil, _max_version, _)
       when not is_nil(deleted_at),
       do: []

  # Do nothing if fields are unchanged and current metadata is not deleted
  defp operations(
         %{latest_metadata: %{fields: fields, deleted_at: nil}},
         fields,
         _max_version,
         _
       ),
       do: []

  # delete current metadata if present and new metadata is absent
  defp operations(%{latest_metadata: %{deleted_at: nil, id: id}}, nil = _fields, _max_version, _) do
    [logical_delete_operation(id)]
  end

  # Insert new metadata if present and current metadata is absent
  defp operations(%{id: structure_id, latest_metadata: nil}, %{} = fields, _max_version, ts) do
    [insert_operation(structure_id, fields, 0, ts)]
  end

  # Insert new metadata if present and current metadata is deleted
  # Use max_version to ensure we don't violate unique constraint
  defp operations(
         %{id: structure_id, latest_metadata: %{deleted_at: deleted_at}},
         %{} = fields,
         max_version,
         ts
       )
       when not is_nil(deleted_at) do
    next_version = max(max_version, 0) + 1
    [insert_operation(structure_id, fields, next_version, ts)]
  end

  # Insert new metadata and logically delete current metadata if changed
  defp operations(
         %{id: structure_id, latest_metadata: %{id: id, version: v}},
         %{} = fields,
         _max_version,
         ts
       ) do
    [
      logical_delete_operation(id),
      insert_operation(structure_id, fields, v + 1, ts)
    ]
  end

  defp insert_operation(structure_id, fields, version, ts) do
    %{
      operation: :insert,
      data_structure_id: structure_id,
      fields: fields,
      version: version,
      inserted_at: ts,
      updated_at: ts
    }
  end

  defp logical_delete_operation(structure_metadata_id) do
    %{operation: :logical_delete, id: structure_metadata_id}
  end

  defp delete_metadata_versions(ids, ts) do
    StructureMetadata
    |> select([sm], sm.data_structure_id)
    |> where([sm], is_nil(sm.deleted_at))
    |> where([sm], sm.data_structure_id in ^ids)
    |> Repo.update_all(set: [deleted_at: ts])
  end

  defp select_missing_external_ids(system_id, external_ids) do
    DataStructure
    |> where(system_id: ^system_id)
    |> select([ds], [:id, :external_id])
    |> subquery()
    |> with_cte("external_ids", as: fragment(@unnest_external_ids, ^external_ids))
    |> join(:right, [ds], id in "external_ids", on: ds.external_id == id.external_id)
    |> where([ds, _], is_nil(ds.id))
    |> select([_, i], i.external_id)
    |> Repo.all()
  end

  defp get_max_metadata_versions(structure_ids)
       when is_list(structure_ids) and structure_ids == [] do
    []
  end

  defp get_max_metadata_versions(structure_ids) do
    StructureMetadata
    |> where([sm], sm.data_structure_id in ^structure_ids)
    |> where([sm], is_nil(sm.deleted_at))
    |> group_by([sm], sm.data_structure_id)
    |> select([sm], {sm.data_structure_id, max(sm.version)})
    |> Repo.all()
  end
end
