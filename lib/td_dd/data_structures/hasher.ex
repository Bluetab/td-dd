defmodule TdDd.DataStructures.Hasher do
  @moduledoc """
  This module calculates the hashes of a data structure or records received during
  bulk loading. Three hashes are calculated:

    * `hash` - The hash of the struct's own hashable fields
    * `lhash` - The hash of the struct's hash and its children hashes
    * `ghash` - The hash of the struct's hash and its descendents hashes

  The module also implements the `Task` behaviour to calculate the initial hash of
  data structures in the Repo when they are not already hashed.
  """

  use Task

  import Ecto.Changeset
  import Ecto.Query

  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Repo

  require Logger

  @hash_fields [
    :class,
    :description,
    :external_id,
    :group,
    :metadata,
    :name,
    :type
  ]
  @batch_size 1_000

  def start_link(arg) do
    Task.start_link(__MODULE__, :run, [arg])
  end

  def run(options \\ []) do
    if options[:rehash] do
      reset_hashes(options[:rehash])
    end

    h_count =
      Timer.time(
        fn -> hash_self(1, -1) end,
        fn ms, count ->
          if count > 0, do: Logger.info("Calculated #{count} hashes in #{ms} ms")
        end
      )

    l_count =
      Timer.time(
        fn -> hash_local(1, -1) end,
        fn ms, count ->
          if count > 0, do: Logger.info("Calculated #{count} lhashes in #{ms} ms")
        end
      )

    g_count =
      Timer.time(
        fn -> hash_global(1, -1) end,
        fn ms, count ->
          if count > 0, do: Logger.info("Calculated #{count} ghashes in #{ms} ms")
        end
      )

    Logger.info("All structures are hashed")
    {:ok, hash: h_count, lhash: l_count, ghash: g_count}
  end

  defp reset_hashes(ids) do
    Timer.time(
      fn -> rehash(ids) end,
      fn ms, count ->
        if count > 0, do: Logger.info("Reset #{count} hashes in #{ms} ms")
      end
    )
  end

  defp rehash(%DataStructureVersion{id: id} = dsv) do
    ancestor_ids =
      dsv
      |> DataStructures.get_ancestors()
      |> Enum.map(& &1.id)

    rehash([id | ancestor_ids])
  end

  defp rehash([]), do: 0

  defp rehash(ids) when is_list(ids) do
    {count, _} =
      from(dsv in DataStructureVersion,
        where: dsv.id in ^ids,
        update: [set: [hash: nil, lhash: nil, ghash: nil]]
      )
      |> Repo.update_all([])

    count
  end

  defp hash_self(0, acc), do: acc + 1

  defp hash_self(_, acc) do
    count =
      DataStructureVersion
      |> where([dsv], is_nil(dsv.hash))
      |> join(:inner, [dsv], ds in assoc(dsv, :data_structure))
      |> select([dsv, ds], {dsv, ds.external_id})
      |> limit(^@batch_size)
      |> Repo.all()
      |> Enum.map(fn {dsv, external_id} -> Map.put(dsv, :external_id, external_id) end)
      |> Enum.map(&update_hashes(&1, %{hash: hash(&1)}))
      |> Enum.count()

    hash_self(count, acc + count)
  end

  defp hash_local(0, acc), do: acc + 1

  defp hash_local(_, acc) do
    count =
      DataStructureVersion
      |> where([dsv], is_nil(dsv.lhash))
      |> join(:left, [dsv], child in assoc(dsv, :children))
      |> group_by([dsv, child, rel], dsv.id)
      |> having([dsv, child, rel], count(child.lhash) == count(child.id))
      |> limit(^@batch_size)
      |> Repo.all()
      |> Repo.preload(child_relations: :child)
      |> Enum.map(&update_hashes(&1, %{lhash: tree_hash(&1, :lhash)}))
      |> Enum.count()

    hash_local(count, acc + count)
  end

  defp hash_global(0, acc), do: acc + 1

  defp hash_global(_, acc) do
    count =
      DataStructureVersion
      |> where([dsv], is_nil(dsv.ghash))
      |> join(:left, [dsv], child in assoc(dsv, :children))
      |> group_by([dsv, child, rel], dsv.id)
      |> having([dsv, child, rel], count(child.ghash) == count(child.id))
      |> limit(^@batch_size)
      |> Repo.all()
      |> Repo.preload(child_relations: :child)
      |> Enum.map(&update_hashes(&1, %{ghash: tree_hash(&1, :ghash)}))
      |> Enum.count()

    hash_global(count, acc + count)
  end

  defp update_hashes(%DataStructureVersion{updated_at: updated_at} = dsv, params) do
    dsv
    |> cast(params, [:hash, :lhash, :ghash])
    |> force_change(:updated_at, updated_at)
    |> Repo.update!()
  end

  defp tree_hash(%DataStructureVersion{child_relations: child_relations, hash: own_hash}, type) do
    child_hashes =
      child_relations
      |> Enum.group_by(& &1.relation_type_id, hash_fn(type))
      |> Enum.flat_map(fn {relation_type_id, hashes} ->
        [hash(relation_type_id) | hashes]
      end)

    [own_hash | child_hashes]
    |> hash()
  end

  defp hash_fn(:lhash), do: & &1.child.hash
  defp hash_fn(:ghash), do: & &1.child.ghash

  def hash(record, fields) when is_map(record) do
    record
    |> to_hashable(fields)
    |> Jason.encode!()
    |> hash()
  end

  def to_hashable(record, fields \\ @hash_fields) do
    record
    |> Map.take(fields)
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Map.new()
  end

  def hash(record) when is_map(record) do
    hash(record, @hash_fields)
  end

  def hash(list) when is_list(list) do
    list
    |> Enum.reduce(&:crypto.exor/2)
    |> hash()
  end

  def hash(binary) when is_binary(binary) do
    :crypto.hash(:sha256, binary)
  end

  def hash(integer) when is_integer(integer) do
    integer
    |> to_string()
    |> hash()
  end
end
