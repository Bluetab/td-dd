defmodule TdDq.Functions.Policy do
  @moduledoc "Authorization rules for data quality functions"

  alias TdDq.Permissions

  @behaviour Bodyguard.Policy

  def authorize(:query, %{role: "user"} = claims, _params) do
    Permissions.authorized_any?(claims, [
      :manage_quality_rule_implementations,
      :manage_raw_quality_rule_implementations,
      :create_grant_request
    ])
  end

  def authorize(_action, %{role: "admin"} = _claims, _params), do: true
  def authorize(_action, %{role: "service"} = _claims, _params), do: true

  def authorize(_action, _claims, _params), do: false
end
