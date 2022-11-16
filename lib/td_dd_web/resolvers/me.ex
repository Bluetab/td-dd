defmodule TdDdWeb.Resolvers.Me do
  @moduledoc """
  Absinthe resolvers for current user related entities
  """

  alias TdCache.Permissions
  alias TdCache.UserCache

  def me(_parent, _args, resolution) do
    case claims(resolution) do
      %{user_id: id, user_name: name} -> {:ok, %{id: id, user_name: name}}
      _ -> {:error, :forbidden}
    end
  end

  def roles(_parent, args, resolution) do
    case claims(resolution) do
      %{} = claims -> {:ok, get_roles(claims, args)}
      _ -> {:error, :forbidden}
    end
  end

  defp get_roles(claims, %{domain_id: string_domain_id} = args)
       when is_binary(string_domain_id) do
    domain_id = String.to_integer(string_domain_id)
    get_roles(claims, Map.put(args, :domain_id, domain_id))
  end

  defp get_roles(claims, args) do
    user_roles = get_user_roles(claims, args)

    args
    |> maybe_get_permission_roles()
    |> maybe_intersect_role_sets(user_roles)
    |> MapSet.to_list()
  end

  defp get_user_roles(%{role: "admin"}, _args), do: :all

  defp get_user_roles(%{user_id: user_id}, args) do
    user_id
    |> UserCache.get_roles()
    |> then(fn
      {:ok, nil} -> %{}
      {:ok, roles} -> roles
    end)
    |> Enum.filter(fn {_role, domain_ids} -> filter_roles_by_domain(domain_ids, args) end)
    |> Enum.map(fn {role, _domain_ids} -> role end)
    |> MapSet.new()
  end

  defp filter_roles_by_domain(domain_ids, %{domain_id: domain_id}),
    do: Enum.member?(domain_ids, domain_id)

  defp filter_roles_by_domain(_, _), do: true

  defp maybe_get_permission_roles(%{permission: permission}) do
    permission
    |> Permissions.get_permission_roles()
    |> then(fn {:ok, roles} -> roles end)
    |> MapSet.new()
  end

  defp maybe_get_permission_roles(_), do: nil

  defp maybe_intersect_role_sets(permission_roles, :all), do: permission_roles
  defp maybe_intersect_role_sets(nil, user_roles), do: user_roles

  defp maybe_intersect_role_sets(permission_roles, user_roles),
    do: MapSet.intersection(user_roles, permission_roles)

  defp claims(%{context: %{claims: claims}}), do: claims
  defp claims(_), do: nil
end
