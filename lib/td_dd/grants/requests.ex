defmodule TdDd.Grants.Requests do
  @moduledoc """
  The Grant Requests context.
  """

  import Ecto.Query

  alias Ecto.Changeset
  alias Ecto.Multi
  alias TdCache.Permissions
  alias TdCache.UserCache
  alias TdDd.Auth.Claims
  alias TdDd.DataStructures
  alias TdDd.DataStructures.Audit
  alias TdDd.DataStructures.DataStructure
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
    |> update([gr, ds], set: [domain_ids: ds.domain_ids])
  end

  def delete_grant_request_group(%GrantRequestGroup{} = group) do
    Repo.delete(group)
  end

  @spec list_grant_requests(Claims.t(), map) ::
          {:error, Changeset.t()} | {:ok, [GrantRequest.t()]}
  def list_grant_requests(%Claims{} = claims, %{} = params \\ %{}) do
    {_data = %{action: nil, user: nil, limit: 1000},
     _types = %{
       action: :string,
       domain_ids: {:array, :integer},
       group_id: :integer,
       limit: :integer,
       status: :string,
       updated_since: :utc_datetime_usec,
       user_id: :integer,
       user: :string
     }}
    |> Changeset.cast(params, [
      :action,
      :domain_ids,
      :group_id,
      :limit,
      :status,
      :updated_since,
      :user_id,
      :user
    ])
    |> Changeset.apply_action(:update)
    |> do_list_grant_requests(claims)
  end

  defp do_list_grant_requests({:ok, %{action: action, user: user_param} = params}, claims) do
    grant_requests =
      case visible_domain_ids(claims, action, user_param) do
        :none ->
          []

        [] ->
          []

        domain_ids ->
          grant_requests =
            params
            |> Map.drop([:action, :user])
            |> Map.put_new(:domain_ids, domain_ids)
            |> grant_request_query()
            |> Repo.all()
            |> Enum.map(&enrich/1)

          case action do
            "approve" ->
              required = required_approvals()
              user_roles = get_user_roles(claims)

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

  defp visible_domain_ids(%{role: "admin"}, _, _), do: :all

  defp visible_domain_ids(%{role: "service"}, _, _), do: :all

  defp visible_domain_ids(_claims, _action, "me"), do: :all

  defp visible_domain_ids(_claims, nil, _), do: :none

  defp visible_domain_ids(%{jti: jti}, "approve", _) do
    Permissions.permitted_domain_ids(jti, :approve_grant_request)
  end

  def get_grant_request!(id, claims, opts \\ []) do
    required = required_approvals()
    user_roles = get_user_roles(claims)

    opts
    |> Map.new()
    |> grant_request_query()
    |> Repo.get!(id)
    |> Repo.preload([:approvals])
    |> with_missing_roles(required, user_roles)
    |> enrich()
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
      |> select_merge([gr, s], %{
        current_status: s.status,
        status_reason: s.reason,
        updated_at: s.inserted_at
      })

    clauses
    |> Map.put_new(:preload, [:group, data_structure: :current_version])
    |> Enum.reduce(query, fn
      {:preload, preloads}, q ->
        preload(q, ^preloads)

      {:status, status}, q ->
        where_status(q, status)

      {:updated_since, ts}, q ->
        where(q, [_gr, s], s.inserted_at > ^ts)

      {:domain_ids, :all}, q ->
        q

      {:domain_ids, domain_ids}, q ->
        where(q, [gr], fragment("? && ?", gr.domain_ids, ^domain_ids))

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
        %{user_id: user_id} = claims,
        %GrantRequest{id: id, domain_ids: domain_ids, current_status: status} = grant_request,
        params
      ) do
    changeset =
      GrantRequestApproval.changeset(
        %GrantRequestApproval{
          grant_request_id: id,
          user_id: user_id,
          domain_ids: domain_ids,
          current_status: status
        },
        params,
        claims
      )

    Multi.new()
    |> Multi.insert(:approval, changeset)
    |> maybe_insert_status(grant_request, Changeset.fetch_field!(changeset, :is_rejection))
    |> Multi.run(:audit, Audit, :grant_request_approval_created, [])
    |> Repo.transaction()
    |> enrich()
  end

  defp where_status(query, status) when is_binary(status) do
    case String.split(status, ",") do
      [status] -> where(query, [_gr, s], s.status == ^status)
      [_ | _] = status -> where(query, [_gr, s], s.status in ^status)
      [] -> query
    end
  end

  defp where_status(query, _status), do: query

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

  defp get_user_roles(%{role: "admin"}), do: :all

  defp get_user_roles(%{role: "service"}), do: :all

  defp get_user_roles(%{user_id: user_id}) do
    {:ok, roles} = TdCache.UserCache.get_roles(user_id)
    get_roles_by_domain_map(roles)
  end

  defp get_roles_by_domain_map(nil), do: %{}

  defp get_roles_by_domain_map(roles) do
    roles
    |> Enum.flat_map(&get_role_domain_tuple/1)
    |> Enum.group_by(
      fn {_, domain_id} -> domain_id end,
      fn {role, _} -> role end
    )
    |> Enum.map(fn {domain_id, roles} -> {domain_id, MapSet.new(roles)} end)
    |> Map.new()
  end

  defp get_role_domain_tuple({role, domains}) do
    Enum.flat_map(domains, fn domain_id ->
      child =
        domain_id
        |> TdCache.TaxonomyCache.reachable_domain_ids()
        |> Enum.map(fn domain_id -> {role, domain_id} end)

      child ++ [{role, domain_id}]
    end)
  end

  defp enrich({:ok, target}) do
    {:ok, enrich(target)}
  end

  defp enrich(%{approval: approval} = multi) do
    %{multi | approval: enrich(approval)}
  end

  defp enrich(items) when is_list(items) do
    Enum.map(items, &enrich/1)
  end

  defp enrich(%GrantRequestApproval{user_id: user_id} = approval) do
    case UserCache.get(user_id) do
      {:ok, user} -> %{approval | user: user}
      _ -> approval
    end
  end

  defp enrich(
         %GrantRequest{group: group, data_structure: data_structure, approvals: approvals} =
           request
       ) do
    %{
      request
      | group: enrich(group),
        data_structure: enrich(data_structure),
        approvals: enrich(approvals)
    }
  end

  defp enrich(%GrantRequestGroup{user_id: user_id} = group) do
    case UserCache.get(user_id) do
      {:ok, user} -> %{group | user: user}
      _ -> group
    end
  end

  defp enrich(%DataStructure{current_version: %{id: id}} = ds) do
    current_version = DataStructures.enriched_structure_versions(ids: [id]) |> hd()
    %{ds | current_version: current_version}
  end

  defp enrich(other), do: other

  defp with_missing_roles(
         %{approvals: approvals} = grant_request,
         required_roles,
         :all
       )
       when is_list(approvals) do
    approved_roles = MapSet.new(approvals, & &1.role)

    pending_roles =
      required_roles
      |> MapSet.difference(approved_roles)
      |> MapSet.to_list()

    %{grant_request | pending_roles: pending_roles}
  end

  # @spec with_missing_roles(map, MapSet.t(), map())
  defp with_missing_roles(
         %{approvals: approvals, domain_ids: domain_ids} = grant_request,
         required_roles,
         user_roles
       )
       when is_list(approvals) do
    user_roles_in_domains =
      user_roles
      |> Map.take(domain_ids)
      |> Map.values()
      |> Enum.reduce(MapSet.new(), &MapSet.union/2)

    approved_roles = MapSet.new(approvals, & &1.role)

    pending_roles =
      required_roles
      |> MapSet.difference(approved_roles)
      |> MapSet.intersection(user_roles_in_domains)
      |> MapSet.to_list()

    %{grant_request | pending_roles: pending_roles}
  end

  defp with_missing_roles(grant_request, _, _) do
    grant_request
  end
end
