defmodule TdDd.Permissions do
  @moduledoc """
  The Permissions context.
  """

  alias TdDd.Auth.Claims

  @permission_resolver Application.compile_env(:td_dd, :permission_resolver)

  def get_domain_permissions(%Claims{jti: jti}) do
    @permission_resolver.get_acls_by_resource_type(jti, "domain")
  end

  @doc """
  Check if authenticated user has a permission in any domain.

  ## Examples

      iex> authorized?(%Claims{}, "create")
      false

  """
  def authorized?(%Claims{jti: jti}, permission) do
    @permission_resolver.has_permission?(jti, permission)
  end

  @doc """
  Check if authenticated user has a permission in a domain.

  ## Examples

      iex> authorized?(%Claims{}, "create", 12)
      false

  """
  def authorized?(%Claims{jti: jti}, permission, domain_id) do
    @permission_resolver.has_permission?(jti, permission, "domain", domain_id)
  end

  @doc """
  Check if authenticated user has a any permission in a domain.

  ## Examples

      iex> authorized_any?(%Claims{}, [:create, :delete], "business_concept", 12)
      false

  """
  def authorized_any?(%Claims{jti: jti}, permissions, domain_id) do
    @permission_resolver.has_any_permission?(jti, permissions, "domain", domain_id)
  end
end
