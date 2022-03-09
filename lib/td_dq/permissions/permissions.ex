defmodule TdDq.Permissions do
  @moduledoc """
  The Permissions context.
  """

  alias TdDq.Auth.Claims

  def authorized?(%Claims{jti: jti}, permission, domain_id) do
    TdCache.Permissions.has_permission?(jti, permission, "domain", domain_id)
  end

  def authorized?(%Claims{jti: jti}, permission) do
    TdCache.Permissions.has_permission?(jti, permission)
  end
end
