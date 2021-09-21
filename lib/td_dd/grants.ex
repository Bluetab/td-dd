defmodule TdDd.Grants do
  @moduledoc """
  The Grants context.
  """

  import Ecto.Query

  alias Ecto.Changeset
  alias Ecto.Multi
  alias TdCache.Permissions
  alias TdDd.Auth.Claims
  alias TdDd.DataStructures
  alias TdDd.DataStructures.Audit
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Grants.Grant
  alias TdDd.Grants.GrantRequest
  alias TdDd.Grants.GrantRequestGroup
  alias TdDd.Grants.GrantRequestStatus
  alias TdDd.Repo

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
  end

  def update_grant(%Grant{} = grant, params, %Claims{user_id: user_id}) do
    changeset = Grant.changeset(grant, params)

    Multi.new()
    |> Multi.update(:grant, changeset)
    |> Multi.run(:audit, Audit, :grant_updated, [changeset, user_id])
    |> Repo.transaction()
  end

  def delete_grant(%Grant{data_structure: data_structure} = grant, %Claims{user_id: user_id}) do
    Multi.new()
    |> Multi.run(:latest, fn _, _ ->
      {:ok, DataStructures.get_latest_version(data_structure, [:path])}
    end)
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

  def delete_grant_request_group(%GrantRequestGroup{} = grant_request_group) do
    Repo.delete(grant_request_group)
  end

  @spec list_grant_requests(Claims.t(), map) ::
          {:error, Changeset.t()} | {:ok, [GrantRequest.t()]}
  def list_grant_requests(%Claims{} = claims, %{} = params \\ %{}) do
    {_data = %{action: nil},
     _types = %{
       action: :string,
       status: :string,
       domain_ids: {:array, :integer},
       user_id: :integer
     }}
    |> Changeset.cast(params, [:action, :domain_ids, :status, :user_id])
    |> Changeset.apply_action(:update)
    |> do_list_grant_requests(claims)
  end

  defp do_list_grant_requests({:ok, %{action: action} = params}, claims) do
    status_subquery =
      GrantRequestStatus
      |> distinct([s], s.grant_request_id)
      |> order_by([s], desc: s.inserted_at)
      |> subquery()

    query =
      GrantRequest
      |> join(:left, [gr], s in ^status_subquery, on: s.grant_request_id == gr.id)
      |> join(:inner, [gr], ds in assoc(gr, :data_structure))
      |> join(:inner, [gr], grg in assoc(gr, :grant_request_group))
      |> select_merge([gr, status], %{current_status: status.status})
      |> select_merge([gr, status, ds], %{domain_id: ds.domain_id})

    grant_requests =
      params
      |> Map.delete(:action)
      |> Map.put_new(:domain_ids, visible_domain_ids(claims, action))
      |> Enum.reduce(query, fn
        {:status, status}, q -> where(q, [gr, s], s.status == ^status)
        {:domain_ids, :all}, q -> q
        {:domain_ids, domain_ids}, q -> where(q, [gr, _, ds], ds.domain_id in ^domain_ids)
        {:user_id, user_id}, q -> where(q, [..., grg], grg.user_id == ^user_id)
      end)
      |> Repo.all()

    {:ok, grant_requests}
  end

  defp do_list_grant_requests(error, _claims), do: error

  defp visible_domain_ids(_claims, nil), do: :all

  defp visible_domain_ids(%{role: "admin"}, _), do: :all

  defp visible_domain_ids(%{user_id: user_id}, "approve") do
    Permissions.permitted_domain_ids(user_id, :approve_grant_request)
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
