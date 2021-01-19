defmodule TdDq.Permissions do
  @moduledoc """
  The Permissions context.
  """

  import Ecto.Query, warn: false

  alias TdDq.Auth.Claims

  @permission_resolver Application.compile_env(:td_dq, :permission_resolver)

  @doc """
  Check if authenticated user has a permission in a domain.

  ## Examples

      iex> authorized?(%Claims{}, "create", 12)
      false

  """
  def authorized?(%Claims{jti: jti}, permission, business_concept_id) do
    @permission_resolver.has_permission?(jti, permission, "business_concept", business_concept_id)
  end

  def authorized?(%Claims{jti: jti}, permission) do
    @permission_resolver.has_permission?(jti, permission)
  end

  def get_domain_permissions(%Claims{jti: jti}) do
    @permission_resolver.get_acls_by_resource_type(jti, "domain")
  end
end
