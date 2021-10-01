defmodule TdDd.Grants.Requests do
  @moduledoc """
  The Grant Requests context.
  """

  import Ecto.Query

  alias Ecto.Changeset
  alias Ecto.Multi
  alias TdCache.DomainCache
  alias TdCache.Permissions
  alias TdCache.UserCache
  alias TdDd.Auth.Claims
  alias TdDd.Grants.GrantRequest
  alias TdDd.Grants.GrantRequestApproval
  alias TdDd.Grants.GrantRequestGroup
  alias TdDd.Grants.GrantRequestStatus
  alias TdDd.Repo

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
    {_data = %{action: nil, limit: 1000},
     _types = %{
       action: :string,
       domain_ids: {:array, :integer},
       group_id: :integer,
       limit: :integer,
       status: :string,
       updated_since: :utc_datetime_usec,
       user_id: :integer
     }}
    |> Changeset.cast(params, [
      :action,
      :domain_ids,
      :group_id,
      :limit,
      :status,
      :updated_since,
      :user_id
    ])
    |> Changeset.apply_action(:update)
    |> do_list_grant_requests(claims)
  end

  defp do_list_grant_requests({:ok, %{action: action} = params}, claims) do
    grant_requests =
      case visible_domain_ids(claims, action) do
        :none ->
          []

        domain_ids ->
          grant_requests =
            params
            |> Map.delete(:action)
            |> Map.put_new(:domain_ids, domain_ids)
            |> grant_request_query()
            |> Repo.all()
            |> Enum.map(&enrich/1)

          case action do
            "approve" ->
              required = required_approvals()
              user_roles = user_roles_by_domain(claims.user_id)

              grant_requests
              |> Repo.preload([:approvals])
              |> Enum.map(&with_missing_roles(&1, required, user_roles))
              |> Enum.reject(&Enum.empty?(Map.get(&1, :pending_roles, [])))

            _ ->
              grant_requests
          end
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
      |> select_merge([gr, s], %{current_status: s.status, updated_at: s.inserted_at})

    clauses
    |> Map.put_new(:preload, [:group, data_structure: :current_version])
    |> Enum.reduce(query, fn
      {:preload, preloads}, q ->
        preload(q, ^preloads)

      {:status, status}, q ->
        where(q, [_gr, s], s.status == ^status)

      {:updated_since, ts}, q ->
        where(q, [_gr, s], s.inserted_at > ^ts)

      {:domain_ids, :all}, q ->
        q

      {:domain_ids, domain_ids}, q ->
        where(q, [gr], gr.domain_id in ^domain_ids)

      {:user_id, user_id}, q ->
        where(q, [..., grg], grg.user_id == ^user_id)

      {:group_id, group_id}, q ->
        where(q, [g], g.group_id == ^group_id)

      {:limit, lim}, q ->
        limit(q, ^lim)
    end)
  end

  def delete_grant_request(%GrantRequest{} = grant_request) do
    Repo.delete(grant_request)
  end

  def create_approval(
        %{user_id: user_id} = _claims,
        %{id: id, current_status: status} = grant_request,
        params
      ) do
    changeset =
      GrantRequestApproval.changeset(
        %GrantRequestApproval{grant_request_id: id, user_id: user_id, current_status: status},
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
    GrantRequestApproval
    |> where(grant_request_id: ^grant_request_id)
    |> where([a], not a.is_rejection)
    |> select([a], a.role)
    |> Repo.all()
    |> MapSet.new()
  end

  defp user_roles_by_domain(user_id) do
    {:ok, roles} = TdCache.UserCache.get_roles(user_id)

    # roles = %{"role1" => [1, 2, 3], "role2" => [3]}

    # si domain_id 1 tiene los hijos [7, 8]
    roles
    |> Enum.flat_map(fn {role, domains} ->
      Enum.flat_map(domains, fn domain_id ->
        child =
          domain_id
          |> TdCache.DomainCache.get!()
          |> Map.get(:descendent_ids)
          |> String.split(",")
          |> Enum.reject(&(&1 == ""))
          |> Enum.map(fn str_id ->
            {d_id, _} = Integer.parse(str_id)
            {role, d_id}
          end)

        child ++ [{role, domain_id}]
      end)
    end)

    # [{"role1", 1}, {"role1", 7}, {"role1", 8}, {"role1", 2}, {"role1", 3}, {"role2", 3}]
    |> Enum.group_by(
      fn {_, domain_id} -> domain_id end,
      fn {role, _} -> role end
    )
    |> Enum.map(fn {domain_id, roles} -> {domain_id, MapSet.new(roles)} end)
    # %{3 => MapSet<["role1", "role2"]>, 1 => MapSet<["role1"]>, ...}
    |> Map.new()
  end

  defp enrich({:ok, target}) do
    {:ok, enrich(target)}
  end

  defp enrich(%{approval: approval} = multi) do
    %{multi | approval: enrich(approval)}
  end

  defp enrich(%GrantRequestApproval{user_id: user_id, domain_id: domain_id} = approval) do
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

  defp with_missing_roles(
         %{approvals: approvals, domain_id: domain_id} = grant_request,
         required,
         user_roles
       )
       when is_list(approvals) do
    user_roles_on_domain = Map.get(user_roles, domain_id, MapSet.new([]))

    current_approved =
      approvals
      |> Enum.map(& &1.role)
      |> MapSet.new()

    pending_roles =
      required
      |> MapSet.difference(current_approved)
      |> MapSet.intersection(user_roles_on_domain)
      |> MapSet.to_list()

    %{grant_request | pending_roles: pending_roles}
  end

  defp with_missing_roles(grant_request, _, _), do: grant_request
end
