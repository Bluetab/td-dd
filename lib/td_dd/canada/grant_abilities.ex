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

  def can?(%Claims{} = claims, :create_grant, %DataStructure{domain_id: domain_id}) do
    Permissions.authorized?(claims, :manage_grants, domain_id)
  end

  def can?(%Claims{} = claims, :view_grants, %DataStructure{domain_id: domain_id}) do
    Permissions.authorized?(claims, :view_grants, domain_id)
  end

  def can?(%Claims{user_id: user_id}, :show, %Grant{user_id: user_id}) do
    true
  end

  def can?(%Claims{} = claims, :show, %Grant{data_structure: %{domain_id: domain_id}}) do
    Permissions.authorized_any?(claims, [:view_grants, :manage_grants], domain_id)
  end

  def can?(%Claims{} = claims, :update, %Grant{data_structure: %{domain_id: domain_id}}) do
    Permissions.authorized?(claims, :manage_grants, domain_id)
  end

  def can?(%Claims{} = claims, :delete, %Grant{data_structure: %{domain_id: domain_id}}) do
    Permissions.authorized?(claims, :manage_grants, domain_id)
  end

  def can?(%Claims{} = claims, :create_grant_request, domain_id) do
    Permissions.authorized?(claims, :create_grant_request, domain_id)
  end

  def can?(%Claims{user_id: user_id}, :show, %GrantRequestGroup{user_id: user_id}) do
    true
  end

  def can?(_claims, _action, _target), do: false
end
