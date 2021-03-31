defmodule TdDd.Canada.ExecutionAbilities do
  @moduledoc """
  Permissions for executions and execution groups.
  """

  alias TdDd.Auth.Claims
  alias TdDd.Executions.Execution
  alias TdDd.Executions.Group

  import TdDd.Permissions, only: [authorized?: 2]

  def can?(%Claims{role: "admin"}, _action, _target), do: true

  # Service accounts can do anything with executions and execution groups
  def can?(%Claims{role: "service"}, _action, _target), do: true

  def can?(%Claims{} = claims, :list, Execution),
    do: authorized?(claims, :view_data_structures_profile)

  def can?(%Claims{} = claims, :list, Group),
    do: authorized?(claims, :view_data_structures_profile)

  def can?(%Claims{} = claims, :show, Group),
    do: authorized?(claims, :view_data_structures_profile)

  def can?(%Claims{} = claims, :create, Group),
    do: authorized?(claims, :profile_structures)

  def can?(%Claims{}, _action, _target), do: false
end
