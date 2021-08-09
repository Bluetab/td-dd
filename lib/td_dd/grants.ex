defmodule TdDd.Grants do
  @moduledoc """
  The Grants context.
  """

  import Ecto.Query, warn: false

  alias Ecto.Changeset
  alias Ecto.Multi
  alias TdDd.Auth.Claims
  alias TdDd.DataStructures.Audit
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Grants.Grant
  alias TdDd.Grants.GrantRequest
  alias TdDd.Grants.GrantRequestGroup
  alias TdDd.Repo

  def list_grants(params \\ %{}) do
    params
    |> Enum.reduce(Grant, fn
      {:user_id, user_id}, q ->
        where(q, [g], g.user_id == ^user_id)

      {:data_structure_id, data_structure_id}, q ->
        where(q, [g], g.data_structure_id == ^data_structure_id)

      {:overlaps, %{start_date: start_date, end_date: nil}}, q ->
        where(q, [g], g.end_date >= ^start_date or is_nil(g.end_date))

      {:overlaps, %{start_date: start_date, end_date: end_date}}, q ->
        where(
          q,
          [g],
          (g.end_date >= ^start_date or is_nil(g.end_date)) and
            g.start_date <= ^end_date
        )
    end)
    |> Repo.all()
  end

  def get_grant!(id, opts \\ []) do
    Grant
    |> Repo.get!(id)
    |> Repo.preload(opts[:preload] || [])
  end

  def create_grant(params, %{id: data_structure_id} = _data_structure, %Claims{user_id: user_id}) do
    changeset =
      Grant.changeset(%Grant{data_structure_id: data_structure_id, user_id: user_id}, params)

    Multi.new()
    |> Multi.run(:overlap, fn _, _ -> date_range_overlap?(changeset) end)
    |> Multi.insert(:grant, changeset)
    |> Multi.run(:audit, Audit, :grant_created, [changeset, user_id])
    |> Repo.transaction()
  end

  defp date_range_overlap?(%{valid?: true} = changeset) do
    data_structure_id = Changeset.fetch_field!(changeset, :data_structure_id)
    user_id = Changeset.fetch_field!(changeset, :user_id)
    start_date = Changeset.get_field(changeset, :start_date)
    end_date = Changeset.get_field(changeset, :end_date)

    %{
      data_structure_id: data_structure_id,
      user_id: user_id,
      overlaps: %{start_date: start_date, end_date: end_date}
    }
    |> list_grants()
    |> Enum.empty?()
    |> case do
      true -> {:ok, nil}
      false -> {:error, Changeset.add_error(changeset, :date_range, "overlaps")}
    end
  end

  defp date_range_overlap?(_), do: {:ok, nil}

  def update_grant(%Grant{} = grant, params, %Claims{user_id: user_id}) do
    changeset = Grant.changeset(grant, params)

    Multi.new()
    |> Multi.update(:grant, changeset)
    |> Multi.run(:audit, Audit, :grant_updated, [changeset, user_id])
    |> Repo.transaction()
  end

  def delete_grant(%Grant{} = grant, %Claims{user_id: user_id}) do
    Multi.new()
    |> Multi.delete(:grant, grant)
    |> Multi.run(:audit, Audit, :grant_deleted, [user_id])
    |> Repo.transaction()
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

  def update_grant_request_group(%GrantRequestGroup{} = grant_request_group, params) do
    grant_request_group
    |> Repo.preload(:requests)
    |> GrantRequestGroup.changeset(params)
    |> Repo.update()
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
end
