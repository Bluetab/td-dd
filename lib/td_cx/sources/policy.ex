defmodule TdCx.Sources.Policy do
  @moduledoc "Authorization rules for TdCx.Sources"

  @behaviour Bodyguard.Policy

  alias TdCx.Permissions
  alias TdCx.Sources.Source

  def authorize(:view_secrets, %{role: role, user_name: user_name}, %Source{type: type})
      when role in ["admin", "service"] do
    String.downcase(type) == String.downcase(user_name)
  end

  def authorize(:view_secrets, %{role: role, user_name: user_name}, %{"type" => type})
      when role in ["admin", "service"] do
    String.downcase(type) == String.downcase(user_name)
  end

  def authorize(:query, %{role: role} = claims, _params) do
    role in ["admin", "service"] or
      Permissions.has_permission?(claims, :manage_raw_quality_rule_implementations)
  end

  def authorize(_action, %{role: role} = _claims, _params) when role in ["admin", "service"],
    do: true

  def authorize(_action, _claims, _params), do: false
end
