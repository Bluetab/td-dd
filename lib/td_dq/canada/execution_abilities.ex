defmodule TdDq.Canada.ExecutionAbilities do
  @moduledoc """
  Permissions for rule executions and execution groups.
  """

  alias TdDq.Accounts.User
  alias TdDq.Executions.Execution
  alias TdDq.Executions.Group

  import TdDq.Permissions, only: [authorized?: 2]

  def can?(%User{} = user, :list, Execution), do: authorized?(user, :view_quality_rule)
  def can?(%User{} = user, :list, Group), do: authorized?(user, :view_quality_rule)
  def can?(%User{} = user, :show, Group), do: authorized?(user, :view_quality_rule)

  def can?(%User{} = user, :create, Group),
    do: authorized?(user, :execute_quality_rule_implementations)
end
