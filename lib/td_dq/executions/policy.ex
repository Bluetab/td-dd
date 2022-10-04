defmodule TdDq.Executions.Policy do
  @moduledoc "Authorization rules for quality executions"

  alias TdDq.Permissions

  @behaviour Bodyguard.Policy

  def authorize(:list_executions, %{role: "user"} = claims, _params),
    do: Permissions.authorized?(claims, :view_quality_rule)

  def authorize(:list_groups, %{role: "user"} = claims, _params),
    do: Permissions.authorized?(claims, :view_quality_rule)

  def authorize(:get_group, %{role: "user"} = claims, _params),
    do: Permissions.authorized?(claims, :view_quality_rule)

  def authorize(:create_group, %{role: "user"} = claims, _params),
    do: Permissions.authorized?(claims, :execute_quality_rule_implementations)

  # Admin and service accounts can do anything with executions and execution groups
  def authorize(_action, %{role: "service"}, _params), do: true
  def authorize(_action, %{role: "admin"}, _params), do: true

  def authorize(_action, _claims, _params), do: false
end
