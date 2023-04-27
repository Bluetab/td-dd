defmodule TdDd.Grants.Requests do
  @moduledoc """
  The Grant Requests context.
  """

  import Ecto.Query

  alias Ecto.Changeset
  alias Ecto.Multi
  alias TdCache.Permissions
  alias TdCache.UserCache
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Grants.ApprovalRules
  alias TdDd.Grants.Audit
  alias TdDd.Grants.GrantRequest
  alias TdDd.Grants.GrantRequestApproval
  alias TdDd.Grants.GrantRequestGroup
  alias TdDd.Grants.GrantRequestStatus
  alias TdDd.Repo
  alias Truedat.Auth.Claims

  defdelegate authorize(action, user, params), to: TdDd.Grants.Policy

  def list_grant_request_groups do
    Repo.all(GrantRequestGroup)
  end

  def list_grant_request_groups_by_user_id(user_id) do
    GrantRequestGroup
    |> where(user_id: ^user_id)
    |> Repo.all()
  end

  def get_grant_request_group!(id, opts \\ []) do
    preloads =
      Keyword.get(opts, :preload, [
        :modification_grant,
        requests: [data_structure: :current_version]
      ])

    GrantRequestGroup
    |> preload(^preloads)
    |> Repo.get!(id)
  end

  def create_grant_request_group(
        %{} = params,
        modification_grant \\ nil
      ) do
    changeset =
      GrantRequestGroup.changeset(
        %GrantRequestGroup{},
        params,
        modification_grant
      )

    Multi.new()
    |> Multi.insert(:group, changeset)
    |> Multi.update_all(:requests, &update_domain_ids/1, [])
    |> Multi.insert_all(:statuses, GrantRequestStatus, fn %{requests: {_count, request_ids}} ->
      Enum.map(
        request_ids,
        &%{grant_request_id: &1, status: "pending", inserted_at: DateTime.utc_now()}
      )
    end)
    |> Multi.run(:approval_rules, &maybe_apply_approval_rules(&1, &2))
    |> Multi.run(:audit, Audit, :grant_request_group_created, [])
    |> Repo.transaction()
  end

  defp maybe_apply_approval_rules(_, %{requests: {_, requests}}) do
    requests
    |> Enum.map(&get_grant_request_for_rules!/1)
    |> Enum.map(&ApprovalRules.get_rules_for_request/1)
    |> Enum.flat_map(&flatten_request_rules/1)
    |> Enum.each(fn {claims, request, params, approval_rule_id} ->
      create_approval(claims, request, params, approval_rule_id)
    end)

    {:ok, nil}
  end

  defp flatten_request_rules({request, rules}) do
    rules
    |> Enum.map(fn
      %{action: action, role: role, comment: comment, user_id: user_id, id: approval_rule_id} ->
        case UserCache.get(user_id) do
          {:ok, nil} ->
            nil

          {:ok, %{role: user_role}} ->
            {%{user_id: user_id, role: user_role}, request,
             %{is_rejection: action == "reject", role: role, comment: comment}, approval_rule_id}
        end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp get_grant_request_for_rules!(id) do
    required = required_approvals()

    %{}
    |> grant_request_query()
    |> Repo.get!(id)
    |> Repo.preload([
      :approvals,
      data_structure: [current_version: [:current_metadata, :published_note]]
    ])
    |> with_all_pending_roles(required)
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
       user_id_or_created_by_id: :integer,
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
      :user_id_or_created_by_id,
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
              |> Enum.map(&with_all_pending_roles(&1, required))
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
    |> Repo.preload([:approvals, :group])
    |> with_missing_roles(required, user_roles)
    |> with_all_pending_roles(required)
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
    |> Map.put_new(:preload, group: [:modification_grant], data_structure: :current_version)
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

      {:user_id_or_created_by_id, user_id}, q ->
        where(q, [..., grg], grg.user_id == ^user_id or grg.created_by_id == ^user_id)

      {:group_id, group_id}, q ->
        where(q, [g], g.group_id == ^group_id)

      {:limit, lim}, q ->
        limit(q, ^lim)
    end)
  end

  def latest_grant_request_by_data_structure(data_structure_id, user_id) do
    GrantRequest
    |> where([r], data_structure_id: ^data_structure_id)
    |> join(:inner, [r], g in assoc(r, :group))
    |> where([_, g], g.user_id == ^user_id)
    |> preload(:group)
    |> order_by(desc: :inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  def latest_grant_request_by_data_structures(data_structure_ids, user_id) do

    status_subquery =
      GrantRequestStatus
      |> distinct([s], s.grant_request_id)
      |> order_by([s], desc: s.inserted_at)
      |> subquery()

    GrantRequest
    |> where([r], r.data_structure_id in ^data_structure_ids)
    |> join(:inner, [r], g in assoc(r, :group))
    |> join(:left, [r], s in ^status_subquery, on: s.grant_request_id == r.id)
    |> where([_, g], g.user_id == ^user_id)
    |> select_merge([r, g, s], %{
      current_status: s.status,
      status_reason: s.reason,
      updated_at: s.inserted_at,
      rank: rank() |> over(partition_by: r.data_structure_id, order_by: {:desc, r.inserted_at})
    })
    |> subquery()
    |> where([r], r.rank == 1)
    |> preload(:group)
    |> Repo.all()
  end

  def get_group(grant_request) do
    grant_request
    |> Repo.preload(:group)
    |> Map.get(:group)
  end

  def latest_grant_request_status(grant_request) do
    [status] =
      grant_request
      |> Repo.preload(
        status: from(s in GrantRequestStatus, order_by: [desc: s.inserted_at], limit: 1)
      )
      |> Map.get(:status)

    status
  end

  def delete_grant_request(%GrantRequest{} = grant_request) do
    Repo.delete(grant_request)
  end

  def create_approval(
        %{user_id: user_id} = claims,
        %GrantRequest{id: id, domain_ids: domain_ids, current_status: status} = grant_request,
        params,
        approval_rule_id \\ nil
      ) do
    changeset =
      GrantRequestApproval.changeset(
        %GrantRequestApproval{
          grant_request_id: id,
          user_id: user_id,
          domain_ids: domain_ids,
          current_status: status,
          approval_rule_id: approval_rule_id
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

  defp enrich(%GrantRequestGroup{user_id: user_id, created_by_id: created_by_id} = group) do
    with {:ok, user} <- UserCache.get(user_id),
         {:ok, created_by} <- UserCache.get(created_by_id) do
      group
      |> Map.put(:user, user)
      |> Map.put(:created_by, created_by)
    else
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

  defp with_all_pending_roles(%{approvals: approvals} = grant_request, required_roles)
       when is_list(approvals) do
    approved_roles = MapSet.new(approvals, & &1.role)

    pending_roles =
      required_roles
      |> MapSet.difference(approved_roles)
      |> MapSet.to_list()

    %{grant_request | all_pending_roles: pending_roles}
  end
end
