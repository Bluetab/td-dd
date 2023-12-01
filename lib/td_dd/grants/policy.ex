defmodule TdDd.Grants.Policy do
  @moduledoc "Authorization rules for Grants"

  alias TdDd.DataStructures
  alias TdDd.Grants.ApprovalRule
  alias TdDd.Grants.Grant
  alias TdDd.Grants.GrantRequest
  alias TdDd.Grants.GrantRequestGroup
  alias TdDd.Permissions

  import TdCache.Permissions, only: [permitted_domain_ids: 2, permitted_domain_ids_by_user_id: 2]

  @behaviour Bodyguard.Policy

  def authorize(_action, %{role: "admin"}, _params), do: true

  def authorize(:reindex, %{role: "service"}, _params), do: true

  def authorize(:mutation, %{} = claims, _params),
    do: Permissions.authorized?(claims, :approve_grant_request)

  def authorize(:query, %{} = claims, :latest_grant_request),
    do: Permissions.authorized?(claims, :view_data_structure)

  def authorize(:query, %{} = claims, _params) do
    Permissions.authorized?(claims, :approve_grant_request) or
      Permissions.authorized?(claims, :create_grant_request)
  end

  def authorize(
        :manage_grant_removal_request,
        %{user_id: user_id} = claims,
        %Grant{user_id: user_id, data_structure: data_structure}
      ) do
    not Bodyguard.permit?(DataStructures, :manage_grant_removal, claims, data_structure)
  end

  def authorize(
        :manage_grant_removal,
        %{user_id: user_id} = claims,
        %Grant{user_id: user_id, data_structure: data_structure}
      ) do
    Bodyguard.permit?(DataStructures, :manage_grant_removal, claims, data_structure)
  end

  def authorize(:manage_grant_removal_request, %{} = claims, %Grant{
        data_structure: data_structure
      }) do
    not Bodyguard.permit?(DataStructures, :manage_grant_removal, claims, data_structure) and
      Bodyguard.permit?(DataStructures, :manage_foreign_grant_removal, claims, data_structure)
  end

  def authorize(:manage_grant_removal, %{} = claims, %Grant{
        data_structure: data_structure
      }) do
    Bodyguard.permit?(DataStructures, :manage_grant_removal, claims, data_structure) and
      Bodyguard.permit?(DataStructures, :manage_foreign_grant_removal, claims, data_structure)
  end

  def authorize(:update, claims, %Grant{
        data_structure: %{domain_ids: domain_ids},
        user_id: user_id
      }) do
    if Permissions.authorized?(claims, :create_foreign_grant_request, domain_ids) do
      allow_domain_ids =
        user_id
        |> permitted_domain_ids_by_user_id(:allow_foreign_grant_request)
        |> MapSet.new()

      intersection = MapSet.intersection(MapSet.new(domain_ids), allow_domain_ids)
      !Enum.empty?(intersection)
    else
      false
    end
  end

  def authorize(:view, %{} = _claims, nil), do: true

  def authorize(:view, %{user_id: user_id}, %Grant{user_id: user_id}), do: true

  def authorize(:view, %{} = claims, %Grant{data_structure: data_structure}) do
    Bodyguard.permit?(DataStructures, :view_grants, claims, data_structure) or
      Bodyguard.permit?(DataStructures, :manage_grants, claims, data_structure)
  end

  def authorize(:manage, %{} = claims, %Grant{data_structure: data_structure}) do
    Bodyguard.permit?(DataStructures, :manage_grants, claims, data_structure)
  end

  def authorize(:view, %{} = claims, %ApprovalRule{domain_ids: domain_ids}) do
    Permissions.authorized?(claims, :approve_grant_request, domain_ids)
  end

  def authorize(:view, %{user_id: user_id} = _claims, %GrantRequestGroup{user_id: user_id}),
    do: true

  def authorize(:view, %{user_id: user_id}, %GrantRequest{group: %{user_id: user_id}}), do: true

  def authorize(:view, %{user_id: user_id}, %GrantRequest{group: %{created_by_id: user_id}}),
    do: true

  def authorize(:view, %{} = claims, %GrantRequest{domain_ids: domain_ids}) do
    Permissions.authorized?(claims, :approve_grant_request, domain_ids)
  end

  def authorize(:approve, %{} = claims, %{domain_ids: domain_ids}) do
    Permissions.authorized?(claims, :approve_grant_request, domain_ids)
  end

  def authorize(:cancel, %{user_id: user_id}, %GrantRequest{group: %{user_id: user_id}}), do: true

  def authorize(:cancel, %{} = claims, %GrantRequest{domain_ids: domain_ids}) do
    Permissions.authorized?(claims, :approve_grant_request, domain_ids)
  end

  def authorize(:create_approval_rule, %{} = claims, domain_ids) do
    integer_domain_ids = Enum.map(domain_ids, &String.to_integer/1)
    Permissions.authorized?(claims, :approve_grant_request, integer_domain_ids)
  end

  def authorize(:update_approval_rule, %{user_id: user_id}, %ApprovalRule{user_id: user_id}),
    do: true

  def authorize(:delete_approval_rule, %{user_id: user_id}, %ApprovalRule{user_id: user_id}),
    do: true

  def authorize(:create_grant_request_group, %{}, %{"user_id" => id, "created_by_id" => id}),
    do: true

  def authorize(:create_grant_request_group, %{jti: jti}, %{"user_id" => user_id}) do
    create_domain_ids =
      jti
      |> permitted_domain_ids(:create_foreign_grant_request)
      |> MapSet.new()

    allow_domain_ids =
      user_id
      |> permitted_domain_ids_by_user_id(:allow_foreign_grant_request)
      |> MapSet.new()

    intersection = MapSet.intersection(create_domain_ids, allow_domain_ids)
    !Enum.empty?(intersection)
  end

  def authorize(_action, _claims, _params), do: false
end
