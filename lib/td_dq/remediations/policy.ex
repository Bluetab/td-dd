defmodule TdDq.Remediations.Policy do
  @moduledoc "Authorization rules for remediations"

  @behaviour Bodyguard.Policy
  alias TdDq.Permissions
  alias TdDq.Remediations.Remediation
  alias TdDq.Rules.RuleResult

  def authorize(_action, %{role: "admin"}, _params), do: true
  def authorize(_action, %{role: "service"}, _params), do: true

  def authorize(
        action,
        %{role: "user"} = claims,
        %Remediation{
          rule_result: %RuleResult{
            implementation: %{domain_id: domain_id}
          }
        }
      )
      when action in [:manage_remediations] do
    Permissions.authorized?(claims, :manage_remediations, domain_id)
  end

  def authorize(_action, _claims, _params), do: false
end
