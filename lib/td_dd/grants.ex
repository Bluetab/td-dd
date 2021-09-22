defmodule TdDd.Grants do
  @moduledoc """
  The Grants context.
  """

  import Ecto.Query

  alias Ecto.Changeset
  alias Ecto.Multi
  alias TdCache.DomainCache
  alias TdCache.Permissions
  alias TdCache.UserCache
  alias TdDd.Auth.Claims
  alias TdDd.DataStructures
  alias TdDd.DataStructures.Audit
  alias TdDd.Grants.Approval
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

  def get_grant_request_group!(id, opts \\ []) do
    preloads = Keyword.get(opts, :preload, requests: [data_structure: :current_version])

    GrantRequestGroup
    |> preload(^preloads)
    |> Repo.get!(id)
  end

  def create_grant_request_group(%{} = params, %Claims{user_id: user_id}) do
    changeset = GrantRequestGroup.changeset(%GrantRequestGroup{user_id: user_id}, params)

    Multi.new()
    |> Multi.insert(:group, changeset)
    |> Multi.update_all(:requests, &update_domain_ids/1, [])
    |> Repo.transaction()
  end

  defp update_domain_ids(%{group: %{id: id}}) do
    GrantRequest
    |> select([gr], gr.id)
    |> where([gr], gr.grant_request_group_id == ^id)
    |> join(:inner, [gr], ds in assoc(gr, :data_structure))
    |> update([gr, ds], set: [domain_id: ds.domain_id])
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
       user_id: :integer,
       group_id: :integer
     }}
    |> Changeset.cast(params, [:action, :domain_ids, :status, :user_id, :group_id])
    |> Changeset.apply_action(:update)
    |> do_list_grant_requests(claims)
  end

  defp do_list_grant_requests({:ok, %{action: action} = params}, claims) do
    status_subquery =
      GrantRequestStatus
      |> distinct([s], s.grant_request_id)
      |> order_by([s], desc: s.inserted_at)
      |> subquery()

    grant_requests =
      case visible_domain_ids(claims, action) do
        :none ->
          []

        domain_ids ->
          query =
            GrantRequest
            |> join(:left, [gr], s in ^status_subquery, on: s.grant_request_id == gr.id)
            |> join(:inner, [gr], grg in assoc(gr, :grant_request_group))
            |> select_merge([gr, status], %{current_status: status.status})
            |> preload([:grant_request_group, data_structure: :current_version])

          params
          |> Map.delete(:action)
          |> Map.put_new(:domain_ids, domain_ids)
          |> Enum.reduce(query, fn
            {:status, status}, q -> where(q, [gr, s], s.status == ^status)
            {:domain_ids, :all}, q -> q
            {:domain_ids, domain_ids}, q -> where(q, [gr], gr.domain_id in ^domain_ids)
            {:user_id, user_id}, q -> where(q, [..., grg], grg.user_id == ^user_id)
            {:group_id, group_id}, q -> where(q, [g], g.grant_request_group_id == ^group_id)
          end)
          |> Repo.all()
          |> Enum.map(&enrich/1)
      end

    {:ok, grant_requests}
  end

  defp do_list_grant_requests(error, _claims), do: error

  defp visible_domain_ids(%{role: "admin"}, _), do: :all

  defp visible_domain_ids(%{role: "service"}, _), do: :all

  defp visible_domain_ids(_claims, nil), do: :none

  defp visible_domain_ids(%{user_id: user_id}, "approve") do
    Permissions.permitted_domain_ids(user_id, :approve_grant_request)
  end

  def get_grant_request!(id, opts \\ []) do
    preloads =
      Keyword.get(opts, :preload, [:grant_request_group, data_structure: :current_version])

    GrantRequest
    |> preload(^preloads)
    |> Repo.get!(id)
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

  def create_approval(%{user_id: user_id} = _claims, %{id: id} = _grant_request, params) do
    %Approval{grant_request_id: id, user_id: user_id}
    |> Approval.changeset(params)
    |> Repo.insert()
    |> enrich()
  end

  defp enrich({:ok, target}) do
    {:ok, enrich(target)}
  end

  defp enrich(%Approval{user_id: user_id, domain_id: domain_id} = approval) do
    with {:ok, user} <- UserCache.get(user_id),
         {:ok, domain} <- DomainCache.get(domain_id) do
      %{approval | user: user, domain: domain}
    else
      _ -> approval
    end
  end

  defp enrich(%GrantRequest{grant_request_group: group} = request) do
    %{request | grant_request_group: enrich(group)}
  end

  defp enrich(%GrantRequestGroup{user_id: user_id} = group) do
    case UserCache.get(user_id) do
      {:ok, user} -> %{group | user: user}
      _ -> group
    end
  end

  defp enrich(other), do: other
end
