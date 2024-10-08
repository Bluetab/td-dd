defmodule TdDq.Rules.RuleResults.Policy do
  @moduledoc "Authorization rules for rule results"

  alias TdDq.Permissions
  alias TdDq.Rules.RuleResult

  @behaviour Bodyguard.Policy

  def authorize(_action, %{role: "admin"}, _params), do: true
  def authorize(_action, %{role: "service"}, _params), do: true

  def authorize(:query, %{} = claims, _params),
    do: Permissions.authorized?(claims, :view_quality_rule)

  def authorize(:view, %{} = claims, _params),
    do: Permissions.authorized?(claims, :view_quality_rule)

  def authorize(:upload, %{} = claims, _params),
    do: Permissions.authorized?(claims, :manage_rule_results)

  def authorize(
        :manage_remediations,
        %{} = claims,
        %RuleResult{
          implementation: %{domain_id: domain_id}
        }
      ) do
    Permissions.authorized?(claims, :manage_remediations, domain_id)
  end

  def authorize(_action, _claims, _params), do: false
end
