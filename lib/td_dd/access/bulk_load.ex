defmodule TdDd.Access.BulkLoad do
  @moduledoc """
  Bulk Load accesses from API JSON
  """

  import Ecto.Query

  require Logger

  alias Ecto.Changeset
  alias TdDd.Access
  alias TdDd.Repo

  defdelegate authorize(action, user, params), to: TdDd.Access.Policy

  def bulk_load(accesses) do
    Logger.info("Loading Accesses")

    Timer.time(
      fn -> do_bulk_load(accesses) end,
      fn millis, _ -> Logger.info("Accesses loaded in #{millis}ms") end
    )
  end

  defp do_bulk_load(accesses) do
    external_ids =
      accesses
      |> MapSet.new(fn
        %{"data_structure_external_id" => external_id} -> external_id
        _ -> nil
      end)
      |> MapSet.delete(nil)

    external_id_map =
      from(ds in TdDd.DataStructures.DataStructure,
        where: ds.external_id in ^MapSet.to_list(external_ids),
        select: {ds.external_id, ds.id}
      )
      |> Repo.all()
      |> Map.new()

    existing_external_ids = external_id_map |> Map.keys() |> MapSet.new()
    missing_external_ids = MapSet.difference(external_ids, existing_external_ids)

    now = DateTime.utc_now()

    {valid_changesets, invalid_changesets} =
      accesses
      |> Stream.reject(fn
        %{"data_structure_external_id" => external_id} -> external_id in missing_external_ids
        _ -> false
      end)
      |> Stream.map(&changeset(&1, external_id_map, now))
      |> Enum.split_with(fn %{valid?: valid?} -> valid? end)

    entries = Enum.map(valid_changesets, &changeset_to_entry/1)

    {count, _result} =
      Repo.insert_all(Access, entries,
        conflict_target: [:data_structure_id, :source_user_name, :accessed_at],
        on_conflict: {:replace, [:user_id, :updated_at]}
      )

    {count, invalid_changesets, MapSet.to_list(missing_external_ids)}
  end

  defp changeset(params, external_id_map, ts) do
    external_id = Map.get(external_id_map, Map.get(params, "data_structure_external_id"))

    params
    |> Map.put("data_structure_id", external_id)
    |> Map.put("inserted_at", ts)
    |> Map.put("updated_at", ts)
    |> Access.changeset()
  end

  defp changeset_to_entry(changeset) do
    changeset
    |> Changeset.apply_changes()
    |> Map.take([
      :data_structure_id,
      # :data_structure_external_id,
      :accessed_at,
      :details,
      :id,
      :inserted_at,
      :source_user_name,
      :updated_at,
      :user_id
    ])
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end
end
