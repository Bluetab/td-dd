defmodule TdDd.Access.Policy do
  @moduledoc "Authorization rules for TdDd.Access"

  @behaviour Bodyguard.Policy

  def authorize(_action, %{role: role}, _params) when role in ["admin", "service"], do: true
  def authorize(_action, _claims, _params), do: false
end
