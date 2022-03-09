defmodule TdDd.Permissions do
  @moduledoc """
  The Permissions context.
  """

  alias TdDd.Auth.Claims

  def authorized?(%Claims{jti: jti}, permissions) when is_list(permissions) do
    TdCache.Permissions.has_any_permission_on_resource_type?(jti, permissions, "domain")
  end

  def authorized?(%Claims{jti: jti}, permission) do
    TdCache.Permissions.has_permission?(jti, permission)
  end

  def authorized?(%Claims{jti: jti}, permission, domain_id) do
    TdCache.Permissions.has_permission?(jti, permission, "domain", domain_id)
  end

  def authorized_any?(%Claims{jti: jti}, permissions, domain_id) do
    TdCache.Permissions.has_any_permission?(jti, permissions, "domain", domain_id)
  end
end
