defmodule TdDd.Canada.GrantAbilities do
  @moduledoc """
  Permissions for grants and grant requests.
  """

  import TdCache.Permissions, only: [permitted_domain_ids: 2, permitted_domain_ids_by_user_id: 2]

  alias TdDd.DataStructures.DataStructure
  alias TdDd.Grants.Grant
  alias TdDd.Grants.GrantRequest
  alias TdDd.Grants.GrantRequestGroup
  alias TdDd.Permissions

  def can?(%{role: "admin"}, _action, _target), do: true

  def can?(%{} = claims, :list, GrantRequest) do
    Permissions.authorized?(claims, :approve_grant_request) or
      Permissions.authorized?(claims, :create_grant_request)
  end

  def can?(%{}, _, GrantRequest), do: false

  def can?(%{user_id: user_id}, :cancel, %GrantRequest{group: %{user_id: user_id}}), do: true

  def can?(%{} = claims, :cancel, %GrantRequest{domain_ids: domain_ids}) do
    Permissions.authorized?(claims, :approve_grant_request, domain_ids)
  end

  def can?(%{} = claims, :approve, %GrantRequest{domain_ids: domain_ids}) do
    Permissions.authorized?(claims, :approve_grant_request, domain_ids)
  end

  def can?(%{} = claims, :list, %GrantRequest{domain_ids: domain_ids}) do
    Permissions.authorized?(claims, :approve_grant_request, domain_ids) or
      Permissions.authorized?(claims, :create_grant_request, domain_ids)
  end

  def can?(%{user_id: user_id}, :show, %GrantRequest{group: %{user_id: user_id}}), do: true

  def can?(%{user_id: user_id}, :show, %GrantRequest{group: %{created_by_id: user_id}}), do: true

  def can?(%{}, :create_grant_request_group, %{"user_id" => user_id, "created_by_id" => user_id}),
    do: true

  def can?(%{jti: jti}, :create_grant_request_group, %{"user_id" => user_id}) do
    create_domain_ids =
      jti
      |> permitted_domain_ids(:create_foreign_grant_request)
      |> MapSet.new()

    allow_domain_ids =
      user_id
      |> permitted_domain_ids_by_user_id(:allow_foreign_grant_request)
      |> MapSet.new()

    create_domain_ids
    |> MapSet.intersection(allow_domain_ids)
    |> Enum.empty?()
    |> Kernel.!()
  end

  def can?(%{}, :create_grant_request_group, _), do: false

  def can?(%{} = claims, :create_foreign_grant_request, domain_ids) do
    Permissions.authorized?(claims, :create_foreign_grant_request, domain_ids)
  end

  def can?(%{} = claims, :show, %GrantRequest{domain_ids: domain_ids}) do
    Permissions.authorized?(claims, :approve_grant_request, domain_ids)
  end

  def can?(%{} = claims, :create_grant, %DataStructure{domain_ids: domain_ids}) do
    Permissions.authorized?(claims, :manage_grants, domain_ids)
  end

  def can?(%{} = claims, :view_grants, %DataStructure{domain_ids: domain_ids}) do
    Permissions.authorized?(claims, :view_grants, domain_ids)
  end

  def can?(%{user_id: user_id}, :show, %Grant{user_id: user_id}), do: true

  def can?(%{} = claims, :show, %Grant{data_structure: %{domain_ids: domain_ids}}) do
    Permissions.authorized?(claims, :view_grants, domain_ids) ||
      Permissions.authorized?(claims, :manage_grants, domain_ids)
  end

  def can?(%{} = claims, :update, %Grant{data_structure: %{domain_ids: domain_ids}}) do
    Permissions.authorized?(claims, :manage_grants, domain_ids)
  end

  def can?(%{user_id: user_id}, :update_pending_removal, %Grant{user_id: user_id}), do: true

  def can?(%{} = claims, :update_pending_removal, %Grant{
        data_structure: %{domain_ids: domain_ids}
      }) do
    Permissions.authorized?(claims, :request_grant_removal, domain_ids)
  end

  def can?(%{} = claims, :update_pending_removal, domain_ids) when is_list(domain_ids) do
    Permissions.authorized?(claims, :request_grant_removal, domain_ids)
  end

  def can?(%{} = claims, :delete, %Grant{data_structure: %{domain_ids: domain_ids}}) do
    Permissions.authorized?(claims, :manage_grants, domain_ids)
  end

  def can?(%{} = claims, :create_grant_request, domain_ids) do
    Permissions.authorized?(claims, :create_grant_request, domain_ids)
  end

  def can?(%{user_id: user_id}, :show, %GrantRequestGroup{user_id: user_id}), do: true

  def can?(_claims, _action, _target), do: false
end
