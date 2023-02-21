defmodule TdDd.Grants do
  @moduledoc """
  The Grants context.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias TdCache.UserCache
  alias TdDd.DataStructures
  alias TdDd.DataStructures.Audit
  alias TdDd.Grants.Grant
  alias TdDd.Repo
  alias TdDd.Search.IndexWorker
  alias Truedat.Auth.Claims

  @pagination_params [:order_by, :limit, :before, :after]

  defdelegate authorize(action, user, params), to: __MODULE__.Policy

  def get_grant!(id, opts \\ []) do
    Grant
    |> Repo.get!(id)
    |> Repo.preload(opts[:preload] || [])
    |> maybe_put_user()
  end

  def create_grant(
        params,
        %{id: data_structure_id} = data_structure,
        %Claims{user_id: user_id},
        is_bulk \\ false
      ) do
    changeset =
      %Grant{data_structure_id: data_structure_id}
      |> Grant.create_changeset(params, is_bulk)
      |> Grant.put_data_structure(data_structure)

    Multi.new()
    |> Multi.run(:latest, fn _, _ ->
      {:ok, DataStructures.get_latest_version(data_structure, [:path])}
    end)
    |> Multi.insert(:grant, changeset)
    |> Multi.run(:audit, Audit, :grant_created, [user_id])
    |> Repo.transaction()
    |> reindex_grants(is_bulk)
  end

  def update_grant(%Grant{} = grant, params, %Claims{user_id: user_id}) do
    changeset = Grant.update_changeset(grant, params)

    Multi.new()
    |> Multi.update(:grant, changeset)
    |> Multi.run(:audit, Audit, :grant_updated, [changeset, user_id])
    |> Repo.transaction()
    |> reindex_grants()
  end

  def delete_grant(%Grant{data_structure: data_structure} = grant, %Claims{user_id: user_id}) do
    Multi.new()
    |> Multi.run(:latest, fn _, _ ->
      {:ok, DataStructures.get_latest_version(data_structure, [:path])}
    end)
    |> Multi.delete(:grant, grant)
    |> Multi.run(:audit, Audit, :grant_deleted, [user_id])
    |> Repo.transaction()
    |> on_delete
  end

  def min_max_count(params) do
    params
    |> Map.drop(@pagination_params)
    |> grants_query
    |> select([e], %{count: count(e), min_id: min(e.id), max_id: max(e.id)})
    |> Repo.one()
  end

  def list_active_grants(%{preload: preload} = clauses) do
    filters =
      clauses
      |> Map.new()
      |> Map.drop([:preload])
      |> Map.put_new(:date, Date.utc_today())

    list_grants(%{filters: filters, preload: preload})
  end

  def list_active_grants(clauses) do
    filters =
      clauses
      |> Map.new()
      |> Map.put_new(:date, Date.utc_today())

    list_grants(%{filters: filters})
  end

  def list_grants(params) do
    params
    |> grants_query
    |> Repo.all()
  end

  defp grants_query(params) do
    Enum.reduce(params, Grant, fn
      {:filters, filters}, q ->
        Enum.reduce(filters, q, fn
          {:ids, ids}, q ->
            where(q, [g], g.id in ^ids)

          {:data_structure_ids, ids}, q ->
            where(q, [g], g.data_structure_id in ^ids)

          {:user_ids, user_ids}, q ->
            where(q, [g], g.user_id in ^user_ids)

          {:date, date}, q ->
            where(
              q,
              [g],
              fragment("daterange(?, ?, '[)') @> ?::date", g.start_date, g.end_date, ^date)
            )

          {:start_date, start_date}, q -> date_filter_clause(start_date, :start_date, q)

          {:end_date, end_date}, q -> date_filter_clause(end_date, :end_date, q)

          {:inserted_at, inserted_at}, q -> date_filter_clause(inserted_at, :inserted_at, q)

          {:updated_at, updated_at}, q -> date_filter_clause(updated_at, :updated_at, q)

          {:pending_removal, pr}, q -> where(q, [g], g.pending_removal == ^pr)
        end)
        {:preload, preloads}, q ->
          preload(q, ^preloads)

        {:order_by, order}, q ->
          order_by(q, ^order)

        {:limit, lim}, q ->
          limit(q, ^lim)

        {:before, id}, q ->
          where(q, [e], e.id < type(^id, :integer))

        {:after, id}, q ->
          where(q, [e], e.id > type(^id, :integer))

        _, q ->
          q
      end)
  end

  defp reindex_grants(result, is_bulk \\ false)

  defp reindex_grants({:ok, %{grant: %Grant{id: id}} = multi}, false) do
    IndexWorker.reindex_grants(id)
    {:ok, multi}
  end

  defp reindex_grants({:ok, %{grant: _grant} = multi}, true), do: {:ok, multi}

  defp reindex_grants(error, _), do: error

  defp on_delete({:ok, %{grant: %Grant{id: id}} = multi}) do
    IndexWorker.delete_grants(id)
    {:ok, multi}
  end

  defp maybe_put_user(%Grant{user_id: user_id} = grant) do
    case UserCache.get(user_id) do
      {:ok, user} -> Map.put(grant, :user, user)
      _ -> grant
    end
  end

  defp date_filter_clause(%{"eq" => eq}, column, q) do
    eq_date = Date.from_iso8601!(eq)
    where(
      q,
      [g],
      fragment("?::date = ?::date", ^eq_date, field(g, ^column))
    )
  end

  defp date_filter_clause(%{"gt" => gt, "lt" => lt}, column, q) do
    lt_date = Date.from_iso8601!(lt)
    gt_date = Date.from_iso8601!(gt)
    where(
      q,
      [g],
      fragment("daterange(?, ?, '()') @> ?::date", ^gt_date, ^lt_date, field(g, ^column))
    )
  end

  defp date_filter_clause(%{"gt" => gt}, column, q) do
    gt_date = Date.from_iso8601!(gt)
    where(
      q,
      [g],
      fragment("?::date < ?::date", ^gt_date, field(g, ^column))
    )
  end

  defp date_filter_clause(%{"lt" => lt}, column, q) do
    lt_date = Date.from_iso8601!(lt)
    where(
      q,
      [g],
      fragment("?::date > ?::date", ^lt_date, field(g, ^column))
    )
  end
end
