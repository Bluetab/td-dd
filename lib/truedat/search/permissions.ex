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
