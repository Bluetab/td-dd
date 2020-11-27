  defmodule TdCx.Permissions do
  @moduledoc """
  The Permissions context.
  """

  import Ecto.Query, warn: false

  alias TdCx.Accounts.User
  alias TdCx.Taxonomies.Domain

  @permission_resolver Application.compile_env(:td_cx, :permission_resolver)

  def get_domain_permissions(%User{jti: jti}) do
    @permission_resolver.get_acls_by_resource_type(jti, "domain")
  end

  def has_any_permission_on_resource_type?(%User{} = user, permissions, Domain) do
    user
      |> get_domain_permissions
      |> Enum.flat_map(&(&1.permissions))
      |> Enum.uniq
      |> Enum.any?(&(Enum.member?(permissions, &1)))
  end

  @doc """
  Check if user has a permission in a domain.

  ## Examples

      iex> authorized?(%User{}, "create", 12)
      false

  """
  def authorized?(%User{jti: jti}, permission, domain_id) do
    @permission_resolver.has_permission?(jti, permission, "domain", domain_id)
  end

  def authorized?(_, _, _), do: false
end
