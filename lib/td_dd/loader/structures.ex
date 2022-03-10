defmodule TdDd.Loader.Structures do
  @moduledoc """
  Loader multi support for updating data structure domain_id.
  """
  import Ecto.Query

  alias TdCx.Sources
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

  def update_source_ids(_repo, %{} = _changes, records, source, ts) do
    external_id_map =
      Sources.list_sources()
      |> Map.new(fn %{id: id, external_id: external_id} -> {external_id, id} end)

    source_id = Map.get(external_id_map, source)
    res = update_source_ids(records, source_id, ts)
    {:ok, res}
  end

  def update_source_ids(_records, nil, _ts), do: {0, []}

  def update_source_ids(records, source_id, ts) do
    records
    |> Enum.map(&Map.get(&1, :external_id))
    |> Enum.filter(& &1)
    |> Enum.chunk_every(@chunk_size)
    |> Enum.map(&do_bulk_update_source_ids(&1, source_id, ts))
    |> Enum.reduce({0, []}, fn {count1, ids1}, {count2, ids2} ->
      {count1 + count2, ids1 ++ ids2}
    end)
  end

  defp do_bulk_update_domain_id(external_ids, domain_id, ts) do
    external_ids
    |> structures_by_external_ids()
    |> where([ds], fragment("array_length(?, 1) is null", ds.domain_ids))
    |> Repo.update_all(set: [domain_ids: [domain_id], updated_at: ts])
  end

  defp do_bulk_update_source_ids(external_ids, source_id, ts) do
    external_ids
    |> structures_by_external_ids()
    |> where([ds], ds.source_id != ^source_id)
    |> or_where([ds], is_nil(ds.source_id))
    |> Repo.update_all(set: [source_id: source_id, updated_at: ts])
  end

  defp structures_by_external_ids(external_ids) do
    DataStructure
    |> select([ds], ds.id)
    |> where([ds], ds.external_id in ^external_ids)
  end
end
