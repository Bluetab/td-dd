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

  def can?(%Claims{user_id: user_id}, :cancel, %GrantRequest{group: %{user_id: user_id}}) do
    true
  end

  def can?(%Claims{} = claims, :cancel, %GrantRequest{domain_ids: domain_ids}) do
    Permissions.authorized?(claims, :approve_grant_request, domain_ids)
  end

  def can?(%Claims{} = claims, :approve, %GrantRequest{domain_ids: domain_ids}) do
    Permissions.authorized?(claims, :approve_grant_request, domain_ids)
  end

  def can?(%Claims{} = claims, :list, %GrantRequest{domain_ids: domain_ids}) do
    Permissions.authorized?(claims, :approve_grant_request, domain_ids) or
      Permissions.authorized?(claims, :create_grant_request, domain_ids)
  end

  def can?(%Claims{user_id: user_id}, :show, %GrantRequest{group: %{user_id: user_id}}) do
    true
  end

  def can?(%Claims{user_id: user_id}, :show, %GrantRequest{group: %{created_by_id: user_id}}) do
    true
  end

  def can?(%Claims{}, :create_grant_request_group, %{
        "user_id" => user_id,
        "created_by_id" => user_id
      }) do
    true
  end

  def can?(%Claims{jti: jti}, :create_grant_request_group, %{"user_id" => user_id}) do
    create_domain_ids =
      jti
      |> TdCache.Permissions.permitted_domain_ids(:create_foreign_grant_request)
      |> Enum.into(MapSet.new())

    allow_domain_ids =
      user_id
      |> TdCache.Permissions.permitted_domain_ids_by_user_id(:allow_foreign_grant_request)
      |> Enum.into(MapSet.new())

    create_domain_ids
    |> MapSet.intersection(allow_domain_ids)
    |> Enum.empty?()
    |> Kernel.!()
  end

  def can?(%Claims{}, :create_grant_request_group, _) do
    false
  end

  def can?(%Claims{} = claims, :create_foreign_grant_request, domain_ids) do
    Permissions.authorized?(claims, :create_foreign_grant_request, domain_ids)
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
