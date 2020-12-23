defmodule TdDd.Loader.Structures do
  @moduledoc """
  Loader multi support for updating data structure domain_id.
  """
  import Ecto.Query

  alias TdDd.DataStructures.DataStructure
  alias TdDd.Repo

  @chunk_size 2_000

  def update_domain_ids(_repo, %{} = _changes, records, ts), do: update_domain_ids(records, ts)

  def update_domain_ids(records, ts) do
    res =
      records
      |> Enum.filter(&Map.has_key?(&1, :domain_id))
      |> Enum.group_by(&Map.get(&1, :domain_id), &Map.get(&1, :external_id))
      |> Enum.map(fn {domain_id, external_ids} ->
        bulk_update_domain_id(external_ids, domain_id, ts)
      end)
      |> Enum.reduce({0, []}, fn {count1, ids1}, {count2, ids2} ->
        {count1 + count2, ids1 ++ ids2}
      end)

    {:ok, res}
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

  defp do_bulk_update_domain_id(external_ids, domain_id, ts) do
    DataStructure
    |> select([ds], ds.id)
    |> where([ds], ds.external_id in ^external_ids)
    |> where_domain_id_not(domain_id)
    |> Repo.update_all(set: [domain_id: domain_id, updated_at: ts])
  end

  defp where_domain_id_not(query, nil) do
    where(query, [ds], not is_nil(ds.domain_id))
  end

  defp where_domain_id_not(query, domain_id) do
    where(query, [ds], ds.domain_id != ^domain_id)
  end
end
