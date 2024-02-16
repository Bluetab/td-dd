defmodule TdDd.Loader.Structures do
  @moduledoc """
  Loader multi support for updating data structure domain_ids.
  """
  import Ecto.Query

  alias TdCx.Sources
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.Hierarchy
  alias TdDd.Repo

  @chunk_size 2_000

  def inherit_domain(dsvs, ts) do
    dsv_ids = Enum.map(dsvs, & &1.id)

    first_existing_parent =
      Hierarchy
      |> where([h], h.ancestor_dsv_id not in ^dsv_ids)
      |> where([h], h.dsv_id in ^dsv_ids)
      |> group_by([h], h.dsv_id)
      |> select([h], %{dsv_id: h.dsv_id, ancestor_level: min(h.ancestor_level)})

    inheritable_domains =
      Hierarchy
      |> join(:inner, [h], sh in subquery(first_existing_parent),
        on: h.dsv_id == sh.dsv_id and h.ancestor_level == sh.ancestor_level
      )
      |> join(:left, [h, _sh], ds in DataStructure, on: ds.id == h.ancestor_ds_id)
      |> group_by([_h, _sh, ds], ds.domain_ids)
      |> select([h, _sh, ds], %{
        domain_ids: ds.domain_ids,
        ds_ids: fragment("array_agg(?)", h.ds_id)
      })
      |> Repo.all()

    res =
      Enum.map(inheritable_domains, fn %{domain_ids: domain_ids, ds_ids: ds_ids} ->
        ds_ids
        |> Enum.chunk_every(@chunk_size)
        |> Enum.map(fn ids ->
          DataStructure
          |> select([ds], ds.id)
          |> where([ds], ds.id in ^ids)
          |> Repo.update_all(set: [domain_ids: domain_ids, updated_at: ts])
        end)
      end)
      |> List.flatten()
      |> Enum.reduce({0, []}, fn {count1, ids1}, {count2, ids2} ->
        {count1 + count2, ids1 ++ ids2}
      end)

    {:ok, res}
  end

  def update_domain_ids(_repo, %{} = _changes, records, ts), do: update_domain_ids(records, ts)

  def update_domain_ids(records, ts) do
    res =
      records
      |> Enum.filter(&Map.has_key?(&1, :domain_ids))
      |> Enum.group_by(&Map.get(&1, :domain_ids), &Map.get(&1, :external_id))
      |> Enum.map(fn {domain_ids, external_ids} ->
        bulk_update_domain_ids(external_ids, domain_ids, ts)
      end)
      |> Enum.reduce({0, []}, fn {count1, ids1}, {count2, ids2} ->
        {count1 + count2, ids1 ++ ids2}
      end)

    {:ok, res}
  end

  @spec bulk_update_domain_ids([binary()], list(), DateTime.t()) :: {integer(), [integer()]}
  def bulk_update_domain_ids(external_ids, domain_ids, ts)

  def bulk_update_domain_ids([], _domain_ids, _ts), do: {0, []}
  def bulk_update_domain_ids(_, [] = _domain_ids, _ts), do: {0, []}
  def bulk_update_domain_ids(_, nil = _domain_ids, _ts), do: {0, []}

  def bulk_update_domain_ids(external_ids, domain_ids, ts) do
    external_ids
    |> Enum.chunk_every(@chunk_size)
    |> Enum.map(&do_bulk_update_domain_ids(&1, domain_ids, ts))
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

  defp do_bulk_update_domain_ids(external_ids, domain_ids, ts) do
    external_ids
    |> structures_by_external_ids()
    |> where([ds], fragment("? = '{}'", ds.domain_ids))
    |> Repo.update_all(set: [domain_ids: domain_ids, updated_at: ts])
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
