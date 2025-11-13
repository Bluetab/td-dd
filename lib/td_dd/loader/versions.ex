defmodule TdDd.Loader.Versions do
  @moduledoc """
  Loader multi support for data structure version operations.
  """

  import Ecto.Query

  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.StructureMetadata
  alias TdDd.Repo

  @structure_fields [
    :confidential,
    :domain_ids,
    :external_id,
    :inserted_at,
    :last_change_by,
    :system_id,
    :updated_at
  ]

  @version_fields [
    :class,
    :data_structure_id,
    :description,
    :group,
    :metadata,
    :name,
    :type,
    :version,
    :lhash,
    :ghash,
    :hash,
    :updated_at,
    :inserted_at
  ]

  @doc """
  Insert new data structure versions and their corresponding data structure.
  """
  def insert_new_versions(_repo, %{context: context}, ts), do: insert_new_versions(context, ts)

  defp insert_new_versions(%{structure_id_map: structure_id_map, entries: entries}, ts) do
    entries =
      entries
      |> Map.new(fn %{external_id: external_id} = r -> {external_id, r} end)
      |> Map.drop(Map.keys(structure_id_map))
      |> Enum.map(fn {_external_id, record} ->
        record
        |> Map.put_new(:inserted_at, ts)
        |> Map.put_new(:updated_at, ts)
        |> Map.put_new(:version, 0)
      end)
      |> Enum.sort_by(& &1.external_id)

    ds_entries = Enum.map(entries, &Map.take(&1, @structure_fields))

    {_count, structures} =
      Repo.chunk_insert_all(DataStructure, ds_entries,
        chunk_size: 1000,
        returning: [:id, :external_id]
      )

    dsv_entries =
      structures
      |> Enum.sort_by(& &1.external_id)
      |> Enum.map(& &1.id)
      |> Enum.zip(entries)
      |> Enum.map(fn {id, entry} -> Map.put(entry, :data_structure_id, id) end)
      |> Enum.map(&Map.take(&1, @version_fields))

    res =
      Repo.chunk_insert_all(DataStructureVersion, dsv_entries,
        chunk_size: 1000,
        returning: [:data_structure_id, :id]
      )

    {:ok, res}
  end

  @doc """
  Update existing data structure versions with unchanged lhash but changed
  ghash. In this case, the ghash is updated and deleted_at is set to nil.
  """
  def update_existing_versions(_repo, %{context: context}, ts),
    do: update_existing_versions(context, ts)

  def update_existing_versions(
        %{
          lhash: lhash,
          ghash: ghash,
          entries: entries,
          version_id_map: version_id_map
        },
        ts
      ) do
    version_ids =
      entries
      |> Enum.reject(&Map.has_key?(ghash, &1.ghash))
      |> Enum.filter(&Map.has_key?(lhash, &1.lhash))
      |> Enum.map(fn %{external_id: external_id} ->
        get_in(version_id_map, [external_id, :id])
      end)
      |> Enum.reject(&is_nil/1)

    structure_ids_to_restore =
      if version_ids != [] do
        DataStructureVersion
        |> select([dsv], dsv.data_structure_id)
        |> where([dsv], dsv.id in ^version_ids)
        |> where([dsv], not is_nil(dsv.deleted_at))
        |> Repo.all()
        |> Enum.uniq()
      else
        []
      end

    entries =
      entries
      |> Enum.reject(&Map.has_key?(ghash, &1.ghash))
      |> Enum.filter(&Map.has_key?(lhash, &1.lhash))
      |> Enum.map(fn %{external_id: external_id, ghash: ghash} ->
        %{
          id: get_in(version_id_map, [external_id, :id]),
          ghash: ghash,
          inserted_at: ts,
          updated_at: ts,
          deleted_at: nil
        }
      end)

    res =
      Repo.chunk_insert_all(DataStructureVersion, entries,
        chunk_size: 1000,
        conflict_target: [:id],
        on_conflict: {:replace, [:ghash, :deleted_at, :updated_at]},
        returning: [:data_structure_id, :id]
      )

    restore_metadata_for_structures(structure_ids_to_restore)

    {:ok, res}
  end

  @doc """
  Replace data structure versions whose hash has changed. In this case, the
  current version is logically deleted and a new version is inserted.
  """
  def replace_changed_versions(_repo, %{context: context}, ts),
    do: replace_changed_versions(context, ts)

  defp replace_changed_versions(
         %{
           lhash: lhash,
           ghash: ghash,
           entries: entries,
           structure_id_map: structure_id_map,
           version_id_map: version_id_map
         },
         ts
       ) do
    entries =
      entries
      |> Enum.reject(&Map.has_key?(ghash, &1.ghash))
      # credo:disable-for-next-line
      |> Enum.reject(&Map.has_key?(lhash, &1.lhash))
      |> Enum.flat_map(fn %{external_id: external_id} = r ->
        case Map.get(version_id_map, external_id) do
          nil ->
            []

          %{id: id, version: version} ->
            [
              %{id: id, version: version, inserted_at: ts, deleted_at: ts, updated_at: ts},
              r
              |> Map.take(@version_fields)
              |> Map.merge(%{
                data_structure_id: Map.fetch!(structure_id_map, external_id),
                version: version + 1,
                inserted_at: ts,
                updated_at: ts
              })
            ]
        end
      end)

    res =
      Repo.chunk_insert_all(DataStructureVersion, entries,
        chunk_size: 1000,
        conflict_target: [:id],
        on_conflict: {:replace, [:deleted_at]},
        returning: [:id, :data_structure_id]
      )

    {:ok, res}
  end

  @doc """
  Restore logically deleted data structure versions if they reappear.
  """
  def restore_deleted_versions(_repo, %{context: context}), do: restore_deleted_versions(context)

  defp restore_deleted_versions(%{ghash: ghash}) do
    res =
      ghash
      |> Map.values()
      |> Enum.reject(fn %{deleted_at: deleted_at} -> is_nil(deleted_at) end)
      |> Enum.map(fn %{id: id} -> id end)
      |> do_restore()

    {:ok, res}
  end

  defp do_restore([]), do: {0, []}

  defp do_restore(ids) do
    structure_ids =
      DataStructureVersion
      |> select([dsv], dsv.data_structure_id)
      |> where([dsv], dsv.id in ^ids)
      |> where([dsv], not is_nil(dsv.deleted_at))
      |> Repo.all()
      |> Enum.uniq()

    {count, _} =
      DataStructureVersion
      |> where([dsv], dsv.id in ^ids)
      |> where([dsv], not is_nil(dsv.deleted_at))
      |> Repo.update_all(set: [deleted_at: nil])

    restore_metadata_for_structures(structure_ids)

    {count, structure_ids}
  end

  defp restore_metadata_for_structures([]), do: {0, []}

  defp restore_metadata_for_structures(structure_ids) do
    latest_deleted_metadata =
      StructureMetadata
      |> where([sm], sm.data_structure_id in ^structure_ids)
      |> where([sm], not is_nil(sm.deleted_at))
      |> group_by([sm], sm.data_structure_id)
      |> select([sm], %{
        data_structure_id: sm.data_structure_id,
        max_version: max(sm.version)
      })
      |> subquery()

    StructureMetadata
    |> join(:inner, [sm], ldm in ^latest_deleted_metadata,
      on: sm.data_structure_id == ldm.data_structure_id and sm.version == ldm.max_version
    )
    |> where([sm], not is_nil(sm.deleted_at))
    |> Repo.update_all(set: [deleted_at: nil])
  end

  @doc """
  Logically delete data structure versions whose external_id is not present in
  the structure records, but whose system_id and group are present.
  """
  def delete_missing_versions(
        _repo,
        %{context: %{structure_id_map: structure_id_map}} = _changes,
        structure_records,
        ts
      ) do
    {:ok, do_delete_missing_versions(structure_records, structure_id_map, ts)}
  end

  def delete_missing_versions(_repo, _changes, _structure_records, _ts),
    do: {:error, :missing_context}

  defp do_delete_missing_versions(structure_records, structure_id_map, ts) do
    structure_records
    |> Enum.group_by(
      fn %{system_id: system_id} -> system_id end,
      fn %{group: group, external_id: external_id} ->
        %{group: group, structure_id: Map.get(structure_id_map, external_id)}
      end
    )
    |> Enum.map(&system_groups/1)
    |> Enum.map(&delete_missing_group_structures(&1, ts))
    |> Enum.reduce({0, []}, fn {count1, ids1}, {count2, ids2} ->
      {count1 + count2, ids1 ++ ids2}
    end)
  end

  defp system_groups({system_id, entries}) do
    Enum.reduce(entries, %{system_id: system_id, groups: MapSet.new(), structure_ids: []}, fn
      %{structure_id: nil, group: group}, %{groups: groups} = acc ->
        %{acc | groups: MapSet.put(groups, group)}

      %{structure_id: id, group: group}, %{groups: groups, structure_ids: ids} = acc ->
        %{acc | groups: MapSet.put(groups, group), structure_ids: [id | ids]}
    end)
  end

  defp delete_missing_group_structures(
         %{system_id: system_id, groups: groups, structure_ids: structure_ids},
         ts
       ) do
    delete_structure_versions(system_id, groups, structure_ids, ts)
  end

  defp delete_structure_versions(system_id, groups, structure_ids, ts) do
    DataStructureVersion
    |> where([dsv], is_nil(dsv.deleted_at))
    |> where([dsv], dsv.group in ^MapSet.to_list(groups))
    |> where([dsv], dsv.data_structure_id not in ^structure_ids)
    |> join(:inner, [dsv], ds in assoc(dsv, :data_structure))
    |> where([_, ds], ds.system_id == ^system_id)
    |> select([dsv], dsv.data_structure_id)
    |> Repo.update_all(set: [deleted_at: ts])
  end
end
