defmodule Truedat.Search.Permissions do
  @moduledoc """
  Maps session permissions to search scopes
  """

  def get_roles_by_user(permission, %{role: "admin"}) do
    {:ok, roles} = get_roles_by_permission(permission)

    roles
  end

  def get_roles_by_user(permission, %{user_id: user_id} = _claims) do
    {:ok, roles} = get_roles_by_permission(permission)

    user_roles =
      get_user_cache_roles!(user_id, "domain") ++ get_user_cache_roles!(user_id, "structure")

    MapSet.intersection(MapSet.new(roles), MapSet.new(user_roles)) |> Enum.to_list()
  end

  defp get_roles_by_permission(permission) do
    {status, roles} = TdCache.Permissions.get_permission_roles(permission)

    {status, Enum.sort(roles)}
  end

  defp get_user_cache_roles!(user_id, resource_type) do
    case TdCache.UserCache.get_roles(user_id, resource_type) do
      {:ok, nil} -> []
      {:ok, user_roles} -> Enum.map(user_roles, fn {k, _} -> k end)
    end
  end
end
