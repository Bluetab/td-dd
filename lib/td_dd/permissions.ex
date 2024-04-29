defmodule TdDd.Permissions do
  @moduledoc """
  The Permissions context.
  """

  import TdCache.Permissions,
    only: [
      has_any_permission?: 2,
      has_permission?: 3,
      has_permission?: 4
    ]

  def authorized?(%{jti: jti}, permissions) when is_list(permissions) do
    has_any_permission?(jti, permissions)
  end

  def authorized?(claims, permission, resource_ids \\ :any, resource_type \\ "domain")

  def authorized?(%{jti: jti}, permission, :any, resource_type) do
    has_permission?(jti, permission, resource_type)
  end

  def authorized?(%{jti: jti}, permission, resource_ids, resource_type) do
    has_permission?(jti, permission, resource_type, resource_ids)
  end
end
