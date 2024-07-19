defmodule TdDd.Lineage.Units do
  @moduledoc """
  A context for lineage units
  """

  alias Ecto.Multi
  alias TdDd.Lineage.Units.Edge
  alias TdDd.Lineage.Units.Event
  alias TdDd.Lineage.Units.Node
  alias TdDd.Lineage.Units.Unit
  alias TdDd.Repo

  import Ecto.Query

  @typep multi_error :: {:error, Multi.name(), any(), %{required(Multi.name()) => any()}}
  @typep multi_success :: {:ok, map()}
  @typep multi_result :: multi_success() | multi_error()

  defdelegate authorize(action, user, params), to: TdDd.Lineage.Policy

  def get_by(clauses) do
    Unit
    |> reduce_clauses(clauses)
    |> Repo.one()
    |> case do
      nil -> {:error, :not_found}
      unit -> {:ok, unit}
    end
  end

  def list_units(clauses \\ %{}) do
    Unit
    |> reduce_clauses(clauses)
    |> Repo.all()
  end

  def list_domain_ids do
    Unit
    |> where([u], not is_nil(u.domain_id))
    |> select([u], u.domain_id)
    |> distinct(true)
    |> Repo.all()
  end

  defp reduce_clauses(q, clauses) do
    Enum.reduce(clauses, q, fn
      {:name, name}, q ->
        where(q, [u], u.name == ^name)

      {:deleted, false}, q ->
        where(q, [u], is_nil(u.deleted_at))

      {:status, true}, q ->
        q
        |> join(:left, [u], e in assoc(u, :events))
        |> order_by([u, e], asc: u.id, desc: e.inserted_at)
        |> distinct([u, e], asc: u.id)
        |> select_merge([u, e], %{status: e})

      {:domain, true}, q ->
        where(q, [u], not is_nil(u.domain_id))

      {:preload, preloads}, q ->
        preload(q, ^preloads)
    end)
  end

  def insert_event(%Unit{id: unit_id}, event, info \\ nil) do
    %{unit_id: unit_id, event: event, info: info}
    |> Event.changeset()
    |> Repo.insert()
  end

  def last_updated do
    last_updated_query()
    |> Repo.all()
    |> Enum.at(0)
  end

  def last_updated_query do
    Event
    |> where([e], e.event in ["LoadSucceeded", "Deleted"])
    |> order_by([e], desc: e.inserted_at)
    |> select([e], e.inserted_at)
    |> limit(1)
  end

  def list_nodes(clauses, options \\ []) do
    clauses
    |> Map.new()
    |> Map.put_new(:deleted, false)
    |> Enum.reduce(Node, fn
      {:external_id, external_ids}, q when is_list(external_ids) ->
        where(q, [ds], ds.external_id in ^external_ids)

      {:external_id, external_id}, q ->
        where(q, [ds], ds.external_id == ^external_id)

      {:type, type}, q ->
        where(q, [n], n.type == ^type)

      {:deleted, false}, q ->
        where(q, [n], is_nil(n.deleted_at))

      {:deleted, _true}, q ->
        q
    end)
    |> Repo.all()
    |> Repo.preload(options[:preload] || [])
  end

  def list_relations(clauses) do
    clauses
    |> Map.new()
    |> Map.put_new(:deleted, false)
    |> Enum.reduce(Edge, fn
      {:type, type}, q ->
        where(q, [r], r.type == ^type)

      {:deleted, false}, q ->
        q
        |> join(:inner, [r], n in Node, on: n.id == r.start_id and is_nil(n.deleted_at))
        |> join(:inner, [r], n in Node, on: n.id == r.end_id and is_nil(n.deleted_at))
        |> select([r], r)

      {:deleted, _true}, q ->
        q
    end)
    |> Repo.all()
  end

  def link_nodes(clauses \\ []) do
    alias TdDd.DataStructures.DataStructure

    Repo.transaction(fn ->
      query =
        Node
        |> where([n], is_nil(n.structure_id))
        |> join(:inner, [n], ds in DataStructure, on: ds.external_id == n.external_id)
        |> update([n, ds], set: [structure_id: ds.id])

      {count, _} =
        clauses
        |> Enum.reduce(query, fn
          {:unit_id, unit_id}, q ->
            join(q, :inner, [n], un in "units_nodes",
              on: n.id == un.node_id and un.unit_id == ^unit_id
            )
        end)
        |> Repo.update_all([])

      count
    end)
  end

  def create_unit(%{} = params) do
    params
    |> Unit.changeset()
    |> Repo.insert()
  end

  def update_unit(%Unit{} = unit, %{} = params) do
    unit
    |> Unit.changeset(params)
    |> Repo.update()
  end

  @spec replace_unit(map) :: multi_result()
  def replace_unit(%{"name" => name} = params) do
    case Repo.get_by(Unit, name: name) do
      nil ->
        Multi.new()
        |> Multi.run(:create, fn _, _ -> create_unit(params) end)
        |> Repo.transaction()

      unit ->
        Multi.new()
        |> Multi.run(:delete, fn _, _ -> delete_unit(unit, logical: false) end)
        |> Multi.run(:create, fn _, _ -> create_unit(params) end)
        |> Repo.transaction()
    end
  end

  def delete_unit(%Unit{id: id} = unit, opts \\ []) do
    opts = Keyword.put_new(opts, :logical, true)

    multi =
      Multi.new()
      |> Multi.run(:delete_unit_nodes, fn _, _ -> delete_unit_nodes([unit_id: id], opts) end)
      |> Multi.run(:delete_unit, fn _, _ -> do_delete_unit(unit, opts[:logical]) end)
      |> Multi.run(:delete_nodes, fn _, _ -> delete_orphaned_nodes(opts) end)

    multi =
      if opts[:logical] do
        Multi.run(multi, :insert_event, fn _, _ -> insert_event(unit, "Deleted") end)
      else
        multi
      end

    Repo.transaction(multi)
  end

  defp do_delete_unit(%Unit{} = unit, true = _logical) do
    unit
    |> Unit.changeset(%{deleted_at: DateTime.utc_now()})
    |> Repo.update()
  end

  defp do_delete_unit(%Unit{} = unit, _false) do
    Repo.delete(unit)
  end

  def delete_unit_nodes(clauses, opts) do
    Repo.transaction(fn ->
      clauses
      |> Enum.reduce("units_nodes", fn
        {:unit_id, unit_id}, q -> where(q, [un], un.unit_id == ^unit_id)
        {:node_id, {:not_in, node_ids}}, q -> where(q, [un], un.node_id not in ^node_ids)
      end)
      |> do_delete(opts[:logical])
    end)
  end

  defp delete_orphaned_nodes(opts) do
    Repo.transaction(fn ->
      orphaned_ids =
        Node
        |> join(:left, [n], un in "units_nodes", on: un.node_id == n.id)
        |> where([_, un], is_nil(un.node_id) or not is_nil(un.deleted_at))
        |> select([n], n.id)
        |> distinct(true)

      Node
      |> where([n], n.id in subquery(orphaned_ids))
      |> select([n], n.id)
      |> do_delete(Keyword.get(opts, :logical, false))
    end)
  end

  defp do_delete(queryable, false = _logical) do
    Repo.delete_all(queryable)
  end

  defp do_delete(queryable, _logical) do
    queryable
    |> where([q], is_nil(q.deleted_at))
    |> Repo.update_all(set: [deleted_at: DateTime.utc_now()])
  end
end
