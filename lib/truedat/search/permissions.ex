defmodule Truedat.Search.Permissions do
  @moduledoc """
  Maps session permissions to search scopes
  """

  def get_search_permissions(permissions, %{role: role} = _claims)
      when role in ["admin", "service"] and is_list(permissions) do
    Map.new(permissions, &{&1, :all})
  end

  def get_search_permissions(permissions, claims) when is_list(permissions) do
    permissions
    |> Map.new(&{&1, :none})
    |> do_get_search_permissions(claims)
  end

  def get_roles_by_user(permission, %{role: "admin"}) do
    {:ok, roles} = get_roles_by_permission(permission)

    roles
  end

  def get_roles_by_user(permission, %{user_id: user_id} = _claims) do
    {:ok, roles} = get_roles_by_permission(permission)

    roles
    |> Enum.flat_map(fn role ->
      "domain"
      |> TdCache.AclCache.get_acl_role_resource_domain_ids(role)
      |> Enum.map(fn domain_id -> {role, domain_id} end)
    end)
    |> Enum.filter(fn {role, domain_id} ->
      TdCache.AclCache.has_role?("domain", domain_id, role, user_id)
    end)
    |> Enum.map(fn {role, _domain_id} -> role end)
    |> Enum.uniq()
  end

  defp get_roles_by_permission(permission) do
    {status, roles} = TdCache.Permissions.get_permission_roles(permission)

    {status, Enum.sort(roles)}
  end

  defp do_get_search_permissions(defaults, %{jti: jti} = _claims) do
    session_permissions = TdCache.Permissions.get_session_permissions(jti)
    default_permissions = get_default_permissions(defaults)

    session_permissions
    |> Map.take(Map.keys(defaults))
    |> Map.merge(default_permissions, fn
      _, _, :all -> :all
      _, scope, _ -> scope
    end)
  end

  defp get_default_permissions(defaults) do
    case TdCache.Permissions.get_default_permissions() do
      {:ok, permissions} -> Enum.reduce(permissions, defaults, &Map.replace(&2, &1, :all))
      _ -> defaults
    end
  end
end
