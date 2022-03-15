defmodule TdDd.Permissions do
  @moduledoc """
  The Permissions context.
  """

  alias TdDd.Auth.Claims

  def authorized?(%Claims{jti: jti}, permissions) when is_list(permissions) do
    TdCache.Permissions.has_any_permission?(jti, permissions)
  end

  def authorized?(%Claims{jti: jti}, permission) do
    TdCache.Permissions.has_permission?(jti, permission)
  end

  def authorized?(%Claims{jti: jti}, permission, domain_ids) do
    TdCache.Permissions.has_permission?(jti, permission, "domain", domain_ids)
  end
end
