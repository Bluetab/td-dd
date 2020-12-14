defmodule TdDd.Loader.MutableMetadataLoader do
  @moduledoc """
  Bulk loader support for updating mutable metadata.
  """
  import Ecto.Query

  alias Ecto.Multi
  alias TdDd.DataStructures
  alias TdDd.DataStructures.StructureMetadata
  alias TdDd.Repo

  require Logger

  @chunk_size 1_000

  @spec load([map()], DateTime.t()) :: {:error, any} | {:ok, [integer()]}
  def load([], _), do: {:ok, []}

  def load([_ | _] = records, audit_attrs) do
    records
    |> Map.new(&mutable_metadata_entry/1)
    |> do_load(audit_attrs)
  end

  defp mutable_metadata_entry(%{external_id: external_id, mutable_metadata: %{} = mm})
       when mm != %{} do
    {external_id, mm}
  end

  defp mutable_metadata_entry(%{external_id: external_id}) do
    {external_id, nil}
  end

  defp do_load(%{} = entries_by_external_id, ts) do
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

    count = Enum.count(structure_ids)
    Logger.info("Metadata loaded (upserted=#{count})")

    {:ok, structure_ids}
  end

  defp bulk_operations({chunk, chunk_id}, multi, ts) do
    structures_by_external_id =
      chunk
      |> Enum.map(&elem(&1, 0))
      |> DataStructures.get_latest_metadata_by_external_ids()
      |> Map.new(&{&1.external_id, &1})

    chunk
    |> Enum.flat_map(fn {external_id, entry} ->
      current_structure = Map.get(structures_by_external_id, external_id)
      operations(current_structure, entry, ts)
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
end
