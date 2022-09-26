defmodule TdDd.Grants.Policy do
  @moduledoc "Authorization rules for Grants"

  alias TdDd.DataStructures
  alias TdDd.Grants.Grant
  alias TdDd.Grants.GrantRequest
  alias TdDd.Grants.GrantRequestGroup
  alias TdDd.Permissions

  import TdCache.Permissions, only: [permitted_domain_ids: 2, permitted_domain_ids_by_user_id: 2]

  @behaviour Bodyguard.Policy

  def authorize(_action, %{role: "admin"}, _params), do: true

  def authorize(:query, %{} = claims, _params) do
    Permissions.authorized?(claims, :approve_grant_request) or
      Permissions.authorized?(claims, :create_grant_request)
  end

  def authorize(:request_removal, %{user_id: user_id} = _claims, %Grant{user_id: user_id}),
    do: true

  def authorize(:request_removal, %{} = claims, %Grant{data_structure: data_structure}) do
    Bodyguard.permit?(DataStructures, :request_grant_removal, claims, data_structure)
  end

  def authorize(:view, %{user_id: user_id}, %Grant{user_id: user_id}), do: true

  def authorize(:view, %{} = claims, %Grant{data_structure: data_structure}) do
    Bodyguard.permit?(DataStructures, :view_grants, claims, data_structure) or
      Bodyguard.permit?(DataStructures, :manage_grants, claims, data_structure)
  end

  def authorize(:manage, %{} = claims, %Grant{data_structure: data_structure}) do
    Bodyguard.permit?(DataStructures, :manage_grants, claims, data_structure)
  end

  def authorize(:view, %{user_id: user_id} = _claims, %GrantRequestGroup{user_id: user_id}),
    do: true

  def authorize(:view, %{user_id: user_id}, %GrantRequest{group: %{user_id: user_id}}), do: true

  def authorize(:view, %{user_id: user_id}, %GrantRequest{group: %{created_by_id: user_id}}),
    do: true

  def authorize(:view, %{} = claims, %GrantRequest{domain_ids: domain_ids}) do
    Permissions.authorized?(claims, :approve_grant_request, domain_ids)
  end

  def authorize(:approve, %{} = claims, %GrantRequest{domain_ids: domain_ids}) do
    Permissions.authorized?(claims, :approve_grant_request, domain_ids)
  end

  def authorize(:cancel, %{user_id: user_id}, %GrantRequest{group: %{user_id: user_id}}), do: true

  def authorize(:cancel, %{} = claims, %GrantRequest{domain_ids: domain_ids}) do
    Permissions.authorized?(claims, :approve_grant_request, domain_ids)
  end

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