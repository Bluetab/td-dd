defmodule TdCx.Permissions do
  @moduledoc """
  The Permissions context.
  """

  alias TdCache.Permissions

  def has_permission?(%{jti: jti}, permission) do
    Permissions.has_permission?(jti, permission)
  end

  def authorized?(%{jti: jti}, permission, domain_id) do
    Permissions.has_permission?(jti, permission, "domain", domain_id)
  end
end
