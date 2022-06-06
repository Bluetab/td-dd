defmodule TdDd.Access.BulkLoad do
  @moduledoc """
  Bulk Load accesses from API JSON
  """

  import Ecto.Query
  require Logger

  alias TdDd.Access
  alias TdDd.Repo

  def bulk_load(accesses) do
    Logger.info("Loading Accesses")

    Timer.time(
      fn -> do_bulk_load(accesses) end,
      fn millis, _ -> Logger.info("Accesses loaded in #{millis}ms") end
    )
  end

  defp do_bulk_load(accesses) do
    external_ids =
      Enum.reduce(
        accesses,
        MapSet.new(),
        fn
          %{"data_structure_external_id" => data_structure_external_id}, acc ->
            MapSet.put(acc, data_structure_external_id)

          _, acc ->
            acc
        end
      )

    external_ids_list = MapSet.to_list(external_ids)

    existing_external_ids =
      from(ds in TdDd.DataStructures.DataStructure,
        where: ds.external_id in ^external_ids_list,
        select: ds.external_id
      )
      |> Repo.all()
      |> MapSet.new()

    inexistent_external_ids = MapSet.difference(external_ids, existing_external_ids)

    accesses_existing_ds_external_id =
      Stream.filter(accesses, fn
        %{"data_structure_external_id" => data_structure_external_id} ->
          data_structure_external_id not in inexistent_external_ids

        _ ->
          true
      end)

    now = DateTime.utc_now()

    {valid_item_changesets, invalid_item_changesets} =
      accesses_existing_ds_external_id
      |> Stream.map(fn access_attrs ->
        access_attrs
        |> Map.put("inserted_at", now)
        |> Map.put("updated_at", now)
        |> Access.changeset()
      end)
      |> Enum.split_with(fn %Ecto.Changeset{} = access_changeset -> access_changeset.valid? end)

    list =
      valid_item_changesets
      |> apply()
      |> Enum.to_list()

    {inserted_count, _result} =
      Repo.insert_all(Access, list,
        conflict_target: [:data_structure_external_id, :source_user_name, :accessed_at],
        on_conflict: {:replace, [:user_id, :updated_at]}
      )

    {inserted_count, invalid_item_changesets, MapSet.to_list(inexistent_external_ids)}
  end

  def apply(valid_item_changesets) do
    valid_item_changesets
    |> Stream.map(fn %Ecto.Changeset{} = changeset ->
      changeset
      |> Ecto.Changeset.apply_changes()
      |> clean()
    end)
  end

  # turns %Access{} into a map with only non-nil item values (no association or __meta__ structs)
  def clean(item) do
    item
    |> Map.from_struct()
    # or something similar
    |> Enum.reject(fn
      {_key, nil} ->
        true

      {_key, %{:__struct__ => struct}}
      when struct in [Ecto.Schema.Metadata, Ecto.Association.NotLoaded] ->
        # rejects __meta__: #Ecto.Schema.Metadata<:built, "items">
        # and association: #Ecto.Association.NotLoaded<association :association is not loaded>
        true

      _other ->
        false
    end)
    |> Enum.into(%{})
  end
end
