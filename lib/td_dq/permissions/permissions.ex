defmodule TdDq.Permissions do
  @moduledoc """
  The Permissions context.
  """

  alias TdDd.Auth.Claims, as: TdDdClaims
  alias TdDq.Auth.Claims

  def authorized?(%Claims{jti: jti}, permission, domain_id) do
    TdCache.Permissions.has_permission?(jti, permission, "domain", domain_id)
  end

  def authorized?(%TdDdClaims{jti: jti}, permission, domain_id) do
    TdCache.Permissions.has_permission?(jti, permission, "domain", domain_id)
  end

  def authorized?(%{} = claims, permissions) when is_list(permissions) do
    Enum.all?(permissions, &authorized?(claims, &1))
  end

  def authorized?(%Claims{jti: jti}, permission) do
    TdCache.Permissions.has_permission?(jti, permission)
  end

  def authorized?(%TdDdClaims{jti: jti}, permission) do
    TdCache.Permissions.has_permission?(jti, permission)
  end

  def authorized_any?(%TdDdClaims{jti: jti}, permissions) do
    TdCache.Permissions.has_any_permission?(jti, permissions)
  end
end
