defmodule TdDq.Implementations.Policy do
  @moduledoc "Authorization rules for quality implementations"

  alias TdDq.Implementations.Implementation
  alias TdDq.Permissions

  @behaviour Bodyguard.Policy

  def authorize(:manage_rule_results, %{role: role} = claims, %Implementation{
        domain_id: domain_id
      }) do
    role in ["admin", "service"] or
      Permissions.authorized?(claims, :manage_rule_results, domain_id)
  end

  def authorize(_action, _claims, _params), do: false
end
