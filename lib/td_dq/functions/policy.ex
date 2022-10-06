defmodule TdDq.Functions.Policy do
  @moduledoc "Authorization rules for data quality functions"

  alias TdDq.Permissions

  @behaviour Bodyguard.Policy

  def authorize(:query, %{role: "user"} = claims, _params) do
    Permissions.authorized?(claims, :manage_quality_rule_implementations)
  end

  def authorize(_action, %{role: "admin"} = _claims, _params), do: true
  def authorize(_action, %{role: "service"} = _claims, _params), do: true

  def authorize(_action, _claims, _params), do: false
end
