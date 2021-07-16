defmodule TdDd.Canada.GrantAbilities do
  @moduledoc """
  Permissions for executions and execution groups.
  """
  import TdDd.Permissions, only: [authorized?: 3]

  alias TdDd.Auth.Claims
  alias TdDd.DataStructures.DataStructure

  def can?(%Claims{role: "admin"}, _action, _target), do: true

  # Service accounts can do anything with executions and execution groups
  def can?(%Claims{} = claims, :create_grant, %DataStructure{
        domain_id: domain_id
      }) do
    authorized?(claims, :manage_grants, domain_id)
  end
end
