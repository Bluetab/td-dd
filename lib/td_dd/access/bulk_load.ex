defmodule TdDd.Access.BulkLoad do
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
        fn %{"data_structure_external_id" => data_structure_external_id}, acc ->
          MapSet.put(acc, data_structure_external_id)
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
      Stream.filter(accesses, fn %{"data_structure_external_id" => data_structure_external_id} ->
        data_structure_external_id not in inexistent_external_ids
      end)

    {valid_item_changesets, invalid_item_changesets} =
      accesses_existing_ds_external_id
      |> Stream.map(fn access_attrs -> Access.changeset(access_attrs) end)
      |> Enum.split_with(fn %Ecto.Changeset{} = access_changeset -> access_changeset.valid? end)

    {inserted_count, _result} =
      valid_item_changesets
      |> apply
      |> Enum.to_list()
      |> (fn list -> Repo.insert_all(Access, list, on_conflict: :nothing) end).()

    {inserted_count, invalid_item_changesets, MapSet.to_list(inexistent_external_ids)}
  end

  def apply(valid_item_changesets) do
    valid_item_changesets
    |> Stream.map(fn %Ecto.Changeset{} = changeset ->
      Ecto.Changeset.apply_changes(changeset)
    end)

    # turns item changesets into a list of %Access{} structs
    |> Stream.map(fn %Access{} = item ->
      clean(item)
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
