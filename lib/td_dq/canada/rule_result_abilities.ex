defmodule TdDq.Canada.RuleResultAbilities do
  @moduledoc """
  Permissions for rule results.
  """

  alias TdDq.Auth.Claims
  alias TdDq.Rules.RuleResult

  alias TdDq.Permissions

  def can?(%Claims{role: "service"}, _, RuleResult), do: true

  def can?(%Claims{} = claims, :upload, RuleResult) do
    Permissions.authorized?(claims, :manage_rule_results)
  end
end
