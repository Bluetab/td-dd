defmodule TdCx.Permissions do
  @moduledoc """
  The Permissions context.
  """

  alias TdCx.Auth.Claims

  def has_permission?(%{:__struct__ => type, jti: jti}, permission)
      when type in [TdCx.Auth.Claims, TdDd.Auth.Claims] do
    TdCache.Permissions.has_permission?(jti, permission)
  end

  @doc """
  Check if authenticated user has a permission in a domain.

  ## Examples

      iex> authorized?(%Claims{}, "create", 12)
      false

  """
  def authorized?(%Claims{jti: jti}, permission, domain_id) do
    TdCache.Permissions.has_permission?(jti, permission, "domain", domain_id)
  end

  def authorized?(_, _, _), do: false
end
