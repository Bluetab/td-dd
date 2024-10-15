defmodule TdDq.Executions.Policy do
  @moduledoc "Authorization rules for quality executions"

  alias TdDq.Permissions

  @behaviour Bodyguard.Policy

  # Admin and service accounts can do anything with executions and execution groups
  def authorize(_action, %{role: "service"}, _params), do: true
  def authorize(_action, %{role: "admin"}, _params), do: true

  def authorize(:list_executions, %{} = claims, _params),
    do: Permissions.authorized?(claims, :view_quality_rule)

  def authorize(:list_groups, %{} = claims, _params),
    do: Permissions.authorized?(claims, :view_quality_rule)

  def authorize(:get_group, %{} = claims, _params),
    do: Permissions.authorized?(claims, :view_quality_rule)

  def authorize(:create_group, %{} = claims, _params),
    do: Permissions.authorized?(claims, :execute_quality_rule_implementations)

  def authorize(_action, _claims, _params), do: false
end
