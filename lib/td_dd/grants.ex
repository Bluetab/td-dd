defmodule TdDd.Grants do
  @moduledoc """
  The Grants context.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias TdDd.Auth.Claims
  alias TdDd.DataStructures
  alias TdDd.DataStructures.Audit
  alias TdDd.Grants.Grant
  alias TdDd.Repo
  alias TdDd.Search.IndexWorker

  def get_grant!(id, opts \\ []) do
    Grant
    |> Repo.get!(id)
    |> Repo.preload(opts[:preload] || [])
  end

  def create_grant(
        params,
        %{id: data_structure_id} = data_structure,
        %Claims{user_id: user_id},
        is_bulk \\ false
      ) do
    changeset =
      %Grant{data_structure_id: data_structure_id}
      |> Grant.changeset(params, is_bulk)
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

  def update_grant(%Grant{} = grant, params, %Claims{user_id: user_id}) do
    changeset = Grant.changeset(grant, params, false)

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

  def list_grants(clauses) do
    clauses
    |> Map.new()
    |> Map.put_new(:date, Date.utc_today())
    |> Enum.reduce(Grant, fn
      {:data_structure_ids, ids}, q ->
        where(q, [g], g.data_structure_id in ^ids)

      {:user_id, user_id}, q ->
        where(q, [g], g.user_id == ^user_id)

      {:date, date}, q ->
        where(
          q,
          [g],
          fragment("daterange(?, ?, '[)') @> ?::date", g.start_date, g.end_date, ^date)
        )

      {:preload, preloads}, q ->
        preload(q, ^preloads)
    end)
    |> Repo.all()
  end
end
