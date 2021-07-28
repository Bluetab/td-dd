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

  require Logger

  @chunk_size 1_000
  @unnest_external_ids "select external_id from unnest(?::text[]) t (external_id)"

  @doc """
  Identifies external_ids which do not exist in the specified system
  """
  def missing_external_ids(_repo, _changes, records, %{id: system_id} = _system) do
    records
    |> Enum.map(& &1.external_id)
    |> Enum.chunk_every(10_000)
    |> Enum.flat_map(&select_missing_external_ids(system_id, &1))
    |> case do
      [] -> {:ok, []}
      ids -> {:error, ids}
    end
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

  defp mutable_metadata_entry(%{external_id: external_id, mutable_metadata: %{} = mm})
       when mm != %{} do
    {external_id, mm}
  end

  defp mutable_metadata_entry(%{external_id: external_id}) do
    {external_id, nil}
  end

  defp do_update(%{} = entries_by_external_id, ts) do
    entries_by_external_id
    |> Enum.chunk_every(@chunk_size)
    |> Enum.with_index()
    |> Enum.reduce(Multi.new(), &bulk_operations(&1, &2, ts))
    |> Repo.transaction()
    |> transform_result()
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

    {:ok, structure_ids}
  end

  defp bulk_operations({chunk, chunk_id}, multi, ts) do
    metadata_by_external_id =
      chunk
      |> Enum.map(&elem(&1, 0))
      |> DataStructures.get_latest_metadata_by_external_ids()
      |> Map.new(&{&1.external_id, &1})

    chunk
    |> Enum.flat_map(fn {external_id, entry} ->
      metadata_by_external_id
      |> Map.get(external_id)
      |> operations(entry, ts)
    end)
    |> Enum.group_by(& &1.operation, &Map.delete(&1, :operation))
    |> Enum.reduce(multi, &reduce_multi(&1, &2, chunk_id, ts))
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

  # Do nothing if current and new metadata are nil
  defp operations(%{latest_metadata: nil}, nil, _), do: []

  # Do nothing if current metadata is deleted and new metadata is nil
  defp operations(%{latest_metadata: %{deleted_at: deleted_at}}, nil, _)
       when not is_nil(deleted_at),
       do: []

  # Do nothing if fields are unchanged and current metadata is not deleted
  defp operations(%{latest_metadata: %{fields: fields, deleted_at: nil}}, fields, _), do: []

  # delete current metadata if present and new metadata is absent
  defp operations(%{latest_metadata: %{deleted_at: nil, id: id}}, nil = _fields, _) do
    [logical_delete_operation(id)]
  end

  # Insert new metadata if present and current metadata is absent
  defp operations(%{id: structure_id, latest_metadata: nil}, %{} = fields, ts) do
    [insert_operation(structure_id, fields, 0, ts)]
  end

  # Insert new metadata if present and current metadata is deleted
  defp operations(
         %{id: structure_id, latest_metadata: %{deleted_at: deleted_at, version: v}},
         %{} = fields,
         ts
       )
       when not is_nil(deleted_at) do
    [insert_operation(structure_id, fields, v + 1, ts)]
  end

  # Insert new metadata and logically delete current metadata if changed
  defp operations(%{id: structure_id, latest_metadata: %{id: id, version: v}}, %{} = fields, ts) do
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
end
