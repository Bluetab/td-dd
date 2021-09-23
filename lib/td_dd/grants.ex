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
    |> Multi.insert_all(:statuses, GrantRequestStatus, fn %{requests: {_count, request_ids}} ->
      Enum.map(
        request_ids,
        &%{grant_request_id: &1, status: "pending", inserted_at: DateTime.utc_now()}
      )
    end)
    |> Repo.transaction()
  end

  defp update_domain_ids(%{group: %{id: id}}) do
    GrantRequest
    |> select([gr], gr.id)
    |> where([gr], gr.group_id == ^id)
    |> join(:inner, [gr], ds in assoc(gr, :data_structure))
    |> update([gr, ds], set: [domain_id: ds.domain_id])
  end

  def delete_grant_request_group(%GrantRequestGroup{} = group) do
    Repo.delete(group)
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
    grant_requests =
      case visible_domain_ids(claims, action) do
        :none ->
          []

        domain_ids ->
          params
          |> Map.delete(:action)
          |> Map.put_new(:domain_ids, domain_ids)
          |> grant_request_query()
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
    opts
    |> Map.new()
    |> grant_request_query()
    |> Repo.get!(id)
  end

  defp grant_request_query(%{} = clauses) do
    status_subquery =
      GrantRequestStatus
      |> distinct([s], s.grant_request_id)
      |> order_by([s], desc: s.inserted_at)
      |> subquery()

    query =
      GrantRequest
      |> join(:left, [gr], s in ^status_subquery, on: s.grant_request_id == gr.id)
      |> join(:left, [gr], grg in assoc(gr, :group))
      |> select_merge([gr, s], %{current_status: s.status})

    clauses
    |> Map.put_new(:preload, [:group, data_structure: :current_version])
    |> Enum.reduce(query, fn
      {:preload, preloads}, q -> preload(q, ^preloads)
      {:status, status}, q -> where(q, [gr, s], s.status == ^status)
      {:domain_ids, :all}, q -> q
      {:domain_ids, domain_ids}, q -> where(q, [gr], gr.domain_id in ^domain_ids)
      {:user_id, user_id}, q -> where(q, [..., grg], grg.user_id == ^user_id)
      {:group_id, group_id}, q -> where(q, [g], g.group_id == ^group_id)
    end)
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

  def create_approval(
        %{user_id: user_id} = _claims,
        %{id: id, current_status: status} = grant_request,
        params
      ) do
    changeset =
      Approval.changeset(
        %Approval{grant_request_id: id, user_id: user_id, current_status: status},
        params
      )

    Multi.new()
    |> Multi.insert(:approval, changeset)
    |> maybe_insert_status(grant_request, Changeset.fetch_field!(changeset, :is_rejection))
    |> Repo.transaction()
    |> enrich()
  end

  defp maybe_insert_status(multi, %{id: grant_request_id} = _grant_request, true = _is_rejection) do
    Multi.insert(multi, :status, %GrantRequestStatus{
      status: "rejected",
      grant_request_id: grant_request_id
    })
  end

  defp maybe_insert_status(multi, %{id: grant_request_id} = grant_request, false = _is_rejection) do
    Multi.run(multi, :status, fn _, _ ->
      required = required_approvals()
      approvals = list_approvals(grant_request)

      if MapSet.subset?(required, approvals) do
        Repo.insert(%GrantRequestStatus{
          status: "approved",
          grant_request_id: grant_request_id
        })
      else
        {:ok, nil}
      end
    end)
  end

  defp required_approvals do
    case Permissions.get_permission_roles(:approve_grant_request) do
      {:ok, roles} when is_list(roles) -> MapSet.new(roles)
    end
  end

  defp list_approvals(%{id: grant_request_id}) do
    Approval
    |> where(grant_request_id: ^grant_request_id)
    |> where([a], not a.is_rejection)
    |> select([a], a.role)
    |> Repo.all()
    |> MapSet.new()
  end

  defp enrich({:ok, target}) do
    {:ok, enrich(target)}
  end

  defp enrich(%{approval: approval} = multi) do
    %{multi | approval: enrich(approval)}
  end

  defp enrich(%Approval{user_id: user_id, domain_id: domain_id} = approval) do
    with {:ok, user} <- UserCache.get(user_id),
         {:ok, domain} <- DomainCache.get(domain_id) do
      %{approval | user: user, domain: domain}
    else
      _ -> approval
    end
  end

  defp enrich(%GrantRequest{group: group} = request) do
    %{request | group: enrich(group)}
  end

  defp enrich(%GrantRequestGroup{user_id: user_id} = group) do
    case UserCache.get(user_id) do
      {:ok, user} -> %{group | user: user}
      _ -> group
    end
  end

  defp enrich(other), do: other
end
