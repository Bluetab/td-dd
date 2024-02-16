defmodule TdDd.Permissions do
  @moduledoc """
  The Permissions context.
  """

  import TdCache.Permissions,
    only: [
      has_any_permission?: 2,
      has_permission?: 2,
      has_permission?: 4
    ]

  def authorized?(%{jti: jti}, permissions) when is_list(permissions) do
    has_any_permission?(jti, permissions)
  end

  def authorized?(%{jti: jti}, permission) do
    has_permission?(jti, permission)
  end

  def authorized?(%{jti: jti}, permission, domain_ids) do
    has_permission?(jti, permission, "domain", domain_ids)
  end
end
