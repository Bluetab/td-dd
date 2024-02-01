defmodule TdDq.Canada.RuleResultAbilities do
  @moduledoc """
  Permissions for rule results.
  """

  alias TdDq.Auth.Claims
  alias TdDq.Permissions
  alias TdDq.Rules.RuleResult

  def can?(%{role: "admin"}, _, _), do: true

  def can?(%Claims{role: "service"}, _, RuleResult), do: true

  def can?(%Claims{role: "service"}, _, %RuleResult{}), do: true

  def can?(%Claims{} = claims, :upload, RuleResult) do
    Permissions.authorized?(claims, :manage_rule_results)
  end

  def can?(%{} = claims, :view, %RuleResult{}) do
    Permissions.authorized?(claims, :view_quality_rule)
  end

  def can?(%{} = claims, :view, RuleResult) do
    Permissions.authorized?(claims, :view_quality_rule)
  end

  def can?(%Claims{} = claims, :manage_remediation, %RuleResult{rule: %{domain_id: domain_id}}) do
    Permissions.authorized?(claims, :manage_remediations, domain_id)
  end

  def can?(%Claims{}, _action, _entity), do: false
end
