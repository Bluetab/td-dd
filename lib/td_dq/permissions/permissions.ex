defmodule TdDq.Permissions do
  @moduledoc """
  The Permissions context.
  """

  import TdCache.Permissions,
    only: [
      has_any_permission?: 2,
      has_permission?: 2,
      has_permission?: 4
    ]

  def authorized?(%{jti: jti}, permission, domain_id) do
    has_permission?(jti, permission, "domain", domain_id)
  end

  def authorized?(%{} = claims, permissions) when is_list(permissions) do
    Enum.all?(permissions, &authorized?(claims, &1))
  end

  def authorized?(%{jti: jti}, permission) do
    has_permission?(jti, permission)
  end

  def authorized_any?(%{jti: jti}, permissions) do
    has_any_permission?(jti, permissions)
  end
end
