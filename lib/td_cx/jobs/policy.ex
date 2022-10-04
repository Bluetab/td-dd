defmodule TdCx.Jobs.Policy do
  @moduledoc "Authorization rules for TdCx.Jobs"

  alias TdCx.Permissions

  @behaviour Bodyguard.Policy

  def authorize(action, %{role: "user"} = claims, _params) when action in [:view, :create] do
    Permissions.has_permission?(claims, :profile_structures)
  end

  def authorize(_action, %{role: role}, _params), do: role in ["admin", "service"]

  def authorize(_action, _claims, _params), do: false
end
