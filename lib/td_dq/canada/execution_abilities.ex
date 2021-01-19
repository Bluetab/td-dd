defmodule TdDq.Canada.ExecutionAbilities do
  @moduledoc """
  Permissions for rule executions and execution groups.
  """

  alias TdDq.Auth.Claims
  alias TdDq.Executions.Execution
  alias TdDq.Executions.Group

  import TdDq.Permissions, only: [authorized?: 2]

  def can?(%Claims{} = claims, :list, Execution), do: authorized?(claims, :view_quality_rule)
  def can?(%Claims{} = claims, :list, Group), do: authorized?(claims, :view_quality_rule)
  def can?(%Claims{} = claims, :show, Group), do: authorized?(claims, :view_quality_rule)

  def can?(%Claims{} = claims, :create, Group),
    do: authorized?(claims, :execute_quality_rule_implementations)
end
