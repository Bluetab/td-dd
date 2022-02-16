defmodule TdDd.Search.Permissions do
  @moduledoc """
  Maps session permissions to search scopes
  """

  alias TdDd.Auth.Claims

  @grant_permissions ["manage_grants", "view_grants"]
  @rule_permissions [
    "view_quality_rule",
    "manage_confidential_business_concepts",
    "execute_quality_rule_implementations"
  ]

  def get_search_permissions(claims, :link_data_structure) do
    do_get_search_permissions(["link_data_structure"], claims)
  end

  def get_search_permissions(claims, :view_data_structure) do
    do_get_search_permissions(["view_data_structure"], claims)
  end

  def get_search_permissions(claims, :grants) do
    do_get_search_permissions(@grant_permissions, claims)
  end

  def get_search_permissions(claims, :rules) do
    do_get_search_permissions(@rule_permissions, claims)
  end

  defp do_get_search_permissions(permissions, %Claims{role: role})
       when role in ["admin", "service"] and is_list(permissions) do
    Map.new(permissions, &{&1, :all})
  end

  defp do_get_search_permissions(permissions, claims) when is_list(permissions) do
    permissions
    |> Map.new(&{&1, :none})
    |> do_get_search_permissions(claims)
  end

  defp do_get_search_permissions(defaults, %Claims{jti: jti}) do
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
