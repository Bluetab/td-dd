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

  # defp do_bulk_load(accesses) do
  #   accesses
  #   |> Enum.with_index()
  #   |> Enum.reduce(Ecto.Multi.new(), fn {attrs, idx}, multi ->
  #     Ecto.Multi.insert(multi, {:invite, idx}, Access.changeset(attrs))
  #   end) |> IO.inspect(label: "ENUM REDUCE")
  #   |> Repo.transaction() |> IO.inspect(label: "REPO.TRANSACTION")
  # end

  defp do_bulk_load(accesses) do

    IO.puts("DO_BULK_LOAD")

    external_ids = Enum.reduce(accesses, MapSet.new, fn %{"data_structure_external_id" => data_structure_external_id}, acc ->
      MapSet.put(acc, data_structure_external_id)
    end)

    external_ids_list = MapSet.to_list(external_ids)

    existing_external_ids = (from ds in TdDd.DataStructures.DataStructure, where: ds.external_id in ^external_ids_list, select: ds.external_id)
    |> Repo.all |> MapSet.new

    inexistent_external_ids = MapSet.difference(external_ids, existing_external_ids)

    {accesses_with_ds_external_id, accesses_without_ds_external_id} = Enum.split_with(accesses, fn %{"data_structure_external_id" => data_structure_external_id} -> data_structure_external_id not in inexistent_external_ids end)


    IO.inspect(accesses_with_ds_external_id, label: "ACCESSES_WITH_DS_EXTERNAL_ID")
    IO.inspect(accesses_without_ds_external_id, label: "ACCESSES_WITHOUT_DS_EXTERNAL_ID")


    {valid_item_changesets, invalid_item_changesets} = accesses_with_ds_external_id
    |> Stream.map(fn access_attrs -> Access.changeset(access_attrs) end)
    |> Enum.split_with(fn %Ecto.Changeset{} = access_changeset -> access_changeset.valid? end)

    IO.inspect(valid_item_changesets, label: "VALID_ITEM_CHANGESETS")
    IO.inspect(invalid_item_changesets, label: "INVALID_ITEM_CHANGESETS")
    {inserted_count, _result} = valid_item_changesets
    |> to_map_list
    |> Enum.to_list
    |> (fn list -> Repo.insert_all(Access, list, on_conflict: :nothing) end).()
    {inserted_count, invalid_item_changesets, MapSet.to_list(inexistent_external_ids)}
  end

  def to_map_list(valid_item_changesets) do
    valid_item_changesets
    |> Stream.map(
      fn %Ecto.Changeset{} = changeset ->
        Ecto.Changeset.apply_changes(changeset)
      end) # turns item changesets into a list of %Access{} structs
    |> Stream.map(fn %Access{} = item ->
      clean(item)
    end)
  end

  # turns %Access{} into a map with only non-nil item values (no association or __meta__ structs)
  def clean(item) do
    item
    |> Map.from_struct()
    |> Enum.reject(fn # or something similar
        {_key, nil} ->
          true

        {key, %_struct{}} ->
          # rejects __meta__: #Ecto.Schema.Metadata<:built, "items">
          # and association: #Ecto.Association.NotLoaded<association :association is not loaded>
          true

        _other ->
          false
    end)
    |> Enum.into(%{})
  end
end
