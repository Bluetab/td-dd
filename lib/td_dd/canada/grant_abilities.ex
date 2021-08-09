defmodule TdDd.Canada.GrantAbilities do
  @moduledoc """
  Permissions for executions and execution groups.
  """
  import TdDd.Permissions, only: [authorized?: 3, authorized_any?: 3]

  alias TdDd.Auth.Claims
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Grants.Grant
  alias TdDd.Grants.GrantRequestGroup

  def can?(%Claims{role: "admin"}, _action, _target), do: true

  def can?(%Claims{} = claims, :create_grant, %DataStructure{
        domain_id: domain_id
      }) do
    authorized?(claims, :manage_grants, domain_id)
  end

  def can?(%Claims{user_id: user_id} = claims, :show, %Grant{
        data_structure: %DataStructure{
          domain_id: domain_id
        },
        user_id: grant_user_id
      }) do
    grant_user_id == user_id or authorized_any?(claims, [:view_grants, :manage_grants], domain_id)
  end

  def can?(%Claims{} = claims, :update, %Grant{
        data_structure: %DataStructure{
          domain_id: domain_id
        }
      }) do
    authorized?(claims, :manage_grants, domain_id)
  end

  def can?(%Claims{} = claims, :delete, %Grant{
        data_structure: %DataStructure{
          domain_id: domain_id
        }
      }) do
    authorized?(claims, :manage_grants, domain_id)
  end

  def can?(%Claims{} = claims, :create_grant_request, domain_id) do
    authorized?(claims, :create_grant_request, domain_id)
  end

  def can?(%Claims{user_id: user_id}, :show, %GrantRequestGroup{user_id: params_user_id}) do
    user_id == params_user_id
  end

  def can?(_claims, _action, _target), do: false
end
