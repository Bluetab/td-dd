defmodule TdCx.Jobs.Policy do
  @moduledoc "Authorization rules for TdCx.Jobs"

  alias TdCx.Permissions

  @behaviour Bodyguard.Policy

  def authorize(_action, %{role: role}, _params) when role in ["admin", "service"], do: true

  def authorize(action, claims, _params) when action in [:view, :create] do
    Permissions.has_permission?(claims, :profile_structures)
  end

  def authorize(_action, _claims, _params), do: false
end
