defmodule TdDd.DataStructures.Hasher do
  @moduledoc """
  This module calculates the hashes of a data structure or records received during
  bulk loading. Three hashes are calculated:

    * `hash` - The hash of the struct's own hashable fields
    * `lhash` - The hash of the struct's hash and its childrens hashes
    * `ghash` - The hash of the struct's hash and its descendents hashes

  The module also implements the `Task` behaviour to calculate the initial hash of
  data structures in the Repo when they are not already hashed.
  """

  use Task

  import Ecto.Changeset
  import Ecto.Query

  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.Repo

  require Logger

  @hash_fields [:class, :description, :group, :metadata, :name, :type]
  @batch_size 1_000

  def start_link(_arg) do
    Task.start_link(__MODULE__, :run, name: __MODULE__)
  end

  def run(_options) do
    unless Application.get_env(:td_dd, :env) == :test do
      {ms, count} = Timer.time(fn -> hash_self(1, -1) end)
      if count > 0, do: Logger.info("Calculated #{count} hashes in #{ms} ms")
      {ms, count} = Timer.time(fn -> hash_local(1, -1) end)
      if count > 0, do: Logger.info("Calculated #{count} lhashes in #{ms} ms")
      {ms, count} = Timer.time(fn -> hash_global(1, -1) end)
      if count > 0, do: Logger.info("Calculated #{count} ghashes in #{ms} ms")
      Logger.info("All structures are hashed")
    end
  end

  defp hash_self(0, acc), do: acc + 1

  defp hash_self(_, acc) do
    count =
      from(dsv in DataStructureVersion)
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
      from(dsv in DataStructureVersion)
      |> where([dsv], is_nil(dsv.lhash))
      |> join(:left, [dsv], dsr in assoc(dsv, :children))
      |> group_by([dsv, child, rel], dsv.id)
      |> having([dsv, child, rel], count(child.lhash) == count(child.id))
      |> limit(^@batch_size)
      |> Repo.all()
      |> Repo.preload(:children)
      |> Enum.map(&update_hashes(&1, %{lhash: lhash(&1)}))
      |> Enum.count()

    hash_local(count, acc + count)
  end

  defp hash_global(0, acc), do: acc + 1

  defp hash_global(_, acc) do
    count =
      from(dsv in DataStructureVersion)
      |> where([dsv], is_nil(dsv.ghash))
      |> join(:left, [dsv], dsr in assoc(dsv, :children))
      |> group_by([dsv, child, rel], dsv.id)
      |> having([dsv, child, rel], count(child.ghash) == count(child.id))
      |> limit(^@batch_size)
      |> Repo.all()
      |> Repo.preload(:children)
      |> Enum.map(&update_hashes(&1, %{ghash: ghash(&1)}))
      |> Enum.count()

    hash_global(count, acc + count)
  end

  defp update_hashes(%DataStructureVersion{updated_at: updated_at} = dsv, attrs) do
    dsv
    |> cast(attrs, [:hash, :lhash, :ghash])
    |> force_change(:updated_at, updated_at)
    |> Repo.update!()
  end

  def lhash(%DataStructureVersion{children: children, hash: own_hash}) do
    [own_hash | Enum.map(children, & &1.hash)]
    |> hash()
  end

  def ghash(%DataStructureVersion{children: children, hash: own_hash}) do
    [own_hash | Enum.map(children, & &1.ghash)]
    |> hash()
  end

  def hash(record, fields) when is_map(record) do
    record
    |> Map.take(fields)
    |> Jason.encode!()
    |> hash()
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
end
