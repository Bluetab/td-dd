defmodule TdDd.Grants.Policy do
  @moduledoc "Authorization rules for TdDd.Grants"

  @behaviour Bodyguard.Policy

  def authorize(_action, %{role: "admin"}, _params), do: true
  def authorize(_action, _claims, _params), do: false
end
