defmodule TdDd.Canada.GrantAbilities do
  @moduledoc """
  Permissions for grants and grant requests.
  """

  alias TdDd.Auth.Claims
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Grants.Grant
  alias TdDd.Grants.GrantRequest
  alias TdDd.Grants.GrantRequestGroup
  alias TdDd.Permissions

  def can?(%Claims{role: "admin"}, _action, _target), do: true

  def can?(%Claims{} = claims, :list, GrantRequest) do
    Permissions.authorized?(claims, :approve_grant_request) or
      Permissions.authorized?(claims, :create_grant_request)
  end

  def can?(%Claims{}, _, GrantRequest), do: false

  def can?(%Claims{} = claims, :approve, %GrantRequest{domain_ids: domain_ids}) do
    Permissions.authorized?(claims, :approve_grant_request, domain_ids)
  end

  def can?(%Claims{user_id: user_id}, :show, %GrantRequest{group: %{user_id: user_id}}) do
    true
  end

  def can?(%Claims{} = claims, :show, %GrantRequest{domain_ids: domain_ids}) do
    Permissions.authorized?(claims, :approve_grant_request, domain_ids)
  end

  def can?(%Claims{} = claims, :create_grant, %DataStructure{domain_ids: domain_ids}) do
    Permissions.authorized?(claims, :manage_grants, domain_ids)
  end

  def can?(%Claims{} = claims, :view_grants, %DataStructure{domain_ids: domain_ids}) do
    Permissions.authorized?(claims, :view_grants, domain_ids)
  end

  def can?(%Claims{user_id: user_id}, :show, %Grant{user_id: user_id}) do
    true
  end

  def can?(%Claims{} = claims, :show, %Grant{data_structure: %{domain_ids: domain_ids}}) do
    Permissions.authorized?(claims, :view_grants, domain_ids) ||
      Permissions.authorized?(claims, :manage_grants, domain_ids)
  end

  def can?(%Claims{} = claims, :update, %Grant{data_structure: %{domain_ids: domain_ids}}) do
    Permissions.authorized?(claims, :manage_grants, domain_ids)
  end

  def can?(%Claims{user_id: user_id}, :update_pending_removal, %Grant{user_id: user_id}) do
    true
  end

  def can?(%Claims{} = claims, :update_pending_removal, %Grant{
        data_structure: %{domain_ids: domain_ids}
      }) do
    Permissions.authorized?(claims, :request_grant_removal, domain_ids)
  end

  def can?(%Claims{} = claims, :update_pending_removal, domain_ids) when is_list(domain_ids) do
    Permissions.authorized?(claims, :request_grant_removal, domain_ids)
  end

  def can?(%Claims{} = claims, :delete, %Grant{data_structure: %{domain_ids: domain_ids}}) do
    Permissions.authorized?(claims, :manage_grants, domain_ids)
  end

  def can?(%Claims{} = claims, :create_grant_request, domain_ids) do
    Permissions.authorized?(claims, :create_grant_request, domain_ids)
  end

  def can?(%Claims{user_id: user_id}, :show, %GrantRequestGroup{user_id: user_id}) do
    true
  end

  def can?(_claims, _action, _target), do: false
end
