defmodule TdDq.Canada.ExecutionAbilities do
  @moduledoc """
  Permissions for rule executions and execution groups.
  """

  alias TdDq.Executions.Execution
  alias TdDq.Executions.Group

  import TdDq.Permissions, only: [authorized?: 2]

  # Service accounts can do anything with executions and execution groups
  def can?(%{role: "service"}, _action, _target), do: true

  def can?(%{} = claims, :list, Execution), do: authorized?(claims, :view_quality_rule)
  def can?(%{} = claims, :list, Group), do: authorized?(claims, :view_quality_rule)
  def can?(%{} = claims, :show, Group), do: authorized?(claims, :view_quality_rule)

  def can?(%{} = claims, :create, Group),
    do: authorized?(claims, :execute_quality_rule_implementations)

  def can?(%{}, _action, _target), do: false
end
