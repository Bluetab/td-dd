defmodule TdDd.Grants do
  @moduledoc """
  The Grants context.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias TdDd.Auth.Claims
  alias TdDd.DataStructures
  alias TdDd.DataStructures.Audit
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Grants.Grant
  alias TdDd.Grants.GrantRequest
  alias TdDd.Grants.GrantRequestGroup
  alias TdDd.Repo
  alias TdDd.Search.IndexWorker

  def get_grant!(id, opts \\ []) do
    Grant
    |> Repo.get!(id)
    |> Repo.preload(opts[:preload] || [])
  end

  def create_grant(params, %{id: data_structure_id} = data_structure, %Claims{user_id: user_id}) do
    changeset =
      %Grant{data_structure_id: data_structure_id}
      |> Grant.changeset(params)
      |> Grant.put_data_structure(data_structure)

    Multi.new()
    |> Multi.run(:latest, fn _, _ ->
      {:ok, DataStructures.get_latest_version(data_structure, [:path])}
    end)
    |> Multi.insert(:grant, changeset)
    |> Multi.run(:audit, Audit, :grant_created, [user_id])
    |> Repo.transaction()
    |> reindex_grants()
  end

  defp reindex_grants({:ok, %{grant: %Grant{id: id}} = multi}) do
    IndexWorker.reindex_grants(id)
    {:ok, multi}
  end

  defp reindex_grants(error), do: error

  defp on_delete({:ok, %{grant: %Grant{id: id}} = multi}) do
    IndexWorker.delete_grants(id)
    {:ok, multi}
  end

  def update_grant(%Grant{} = grant, params, %Claims{user_id: user_id}) do
    changeset = Grant.changeset(grant, params)

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

  def list_grant_request_groups do
    Repo.all(GrantRequestGroup)
  end

  def list_grant_request_groups_by_user_id(user_id) do
    GrantRequestGroup
    |> where(user_id: ^user_id)
    |> Repo.all()
  end

  def get_grant_request_group!(id) do
    GrantRequestGroup
    |> Repo.get!(id)
    |> Repo.preload(:requests)
  end

  def get_grant_request_group(id), do: Repo.get(GrantRequestGroup, id)

  def create_grant_request_group(%{} = params, %Claims{user_id: user_id}) do
    %GrantRequestGroup{user_id: user_id}
    |> GrantRequestGroup.changeset(params)
    |> Repo.insert()
  end

  def delete_grant_request_group(%GrantRequestGroup{} = grant_request_group) do
    Repo.delete(grant_request_group)
  end

  def list_grant_requests(grant_request_group_id) do
    GrantRequest
    |> where(grant_request_group_id: ^grant_request_group_id)
    |> Repo.all()
  end

  def get_grant_request!(id), do: Repo.get!(GrantRequest, id)

  def create_grant_request(
        params,
        %GrantRequestGroup{id: group_id, type: group_type},
        %DataStructure{id: data_structure_id}
      ) do
    %GrantRequest{
      grant_request_group_id: group_id,
      data_structure_id: data_structure_id
    }
    |> GrantRequest.changeset(params, group_type)
    |> Repo.insert()
  end

  def update_grant_request(%GrantRequest{} = grant_request, params) do
    group_type =
      case Repo.preload(grant_request, :grant_request_group) do
        %{grant_request_group: %{type: group_type}} -> group_type
        _ -> nil
      end

    grant_request
    |> GrantRequest.changeset(params, group_type)
    |> Repo.update()
  end

  def delete_grant_request(%GrantRequest{} = grant_request) do
    Repo.delete(grant_request)
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
          fragment("daterange(?, ?, '[]') @> ?::date", g.start_date, g.end_date, ^date)
        )

      {:preload, preloads}, q ->
        preload(q, ^preloads)
    end)
    |> Repo.all()
  end
end
