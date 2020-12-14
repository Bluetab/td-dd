defmodule TdDd.Loader.DomainIdLoader do
  @moduledoc """
  Bulk loader support for updating domain id.
  """
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Repo

  import Ecto.Query

  @chunk_size 2_000

  require Logger

  def load(records, ts) do
    {count, ids} =
      records
      |> Enum.filter(&Map.has_key?(&1, :domain_id))
      |> Enum.group_by(&Map.get(&1, :domain_id), &Map.get(&1, :external_id))
      |> Enum.map(fn {domain_id, external_ids} ->
        bulk_update_domain_id(external_ids, domain_id, ts)
      end)
      |> Enum.reduce({0, []}, fn {count1, ids1}, {count2, ids2} ->
        {count1 + count2, ids1 ++ ids2}
      end)

    Logger.info("Domains updated (updated=#{count})")
    {:ok, ids}
  end

  @spec bulk_update_domain_id([binary()], integer(), DateTime.t()) :: {integer(), [integer()]}
  def bulk_update_domain_id(external_ids, domain_id, ts)

  def bulk_update_domain_id([], _domain_id, _ts), do: {0, []}

  def bulk_update_domain_id(external_ids, domain_id, ts) do
    external_ids
    |> Enum.chunk_every(@chunk_size)
    |> Enum.map(&do_bulk_update_domain_id(&1, domain_id, ts))
    |> Enum.reduce({0, []}, fn {count1, ids1}, {count2, ids2} ->
      {count1 + count2, ids1 ++ ids2}
    end)
  end

  defp do_bulk_update_domain_id(external_ids, nil, ts) do
    DataStructure
    |> select([ds], ds.id)
    |> where([ds], ds.external_id in ^external_ids)
    |> where([ds], not is_nil(ds.domain_id))
    |> update(set: [domain_id: nil, updated_at: ^ts])
    |> Repo.update_all([])
  end

  defp do_bulk_update_domain_id(external_ids, domain_id, ts) do
    DataStructure
    |> select([ds], ds.id)
    |> where([ds], ds.external_id in ^external_ids)
    |> where([ds], ds.domain_id != ^domain_id)
    |> update(set: [domain_id: ^domain_id, updated_at: ^ts])
    |> Repo.update_all([])
  end
end
