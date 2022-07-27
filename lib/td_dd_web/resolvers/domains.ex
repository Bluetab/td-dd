defmodule TdDdWeb.Resolvers.Domains do
  @moduledoc """
  Absinthe resolvers for domains
  """

  alias TdCache.Permissions
  alias TdCache.TaxonomyCache

  @actions_to_permissions %{
    "manage_tags" => {[:link_data_structure_tag], []},
    "manage_implementations" =>
      {[:manage_quality_rule_implementations], [:publish_implementation, :manage_segments]},
    "manage_raw_implementations" =>
      {[:manage_raw_quality_rule_implementations], [:publish_implementation, :manage_segments]},
    "manage_ruleless_implementations" =>
      {[
         :manage_quality_rule_implementations,
         :manage_ruleless_implementations
       ], [:publish_implementation, :manage_segments]},
    "manage_raw_ruleless_implementations" =>
      {[
         :manage_raw_quality_rule_implementations,
         :manage_ruleless_implementations
       ], [:publish_implementation, :manage_segments]},
    "can_publish_implementation" => {[:publish_implementation], []},
    "can_manage_segments" => {[:manage_segments], []}
  }

  defp permissions_to_actions(permissions) do
    @actions_to_permissions
    |> Enum.filter(fn {_key, {value, _}} ->
      Enum.empty?(value -- permissions)
    end)
    |> Enum.map(fn {key, _value} -> key end)
  end

  defp with_interested_actions(
         domains,
         %{action: action, with_interested_actions: true},
         resolution
       ) do
    {_, interested_permissions} = Map.get(@actions_to_permissions, action, {[], []})

    interested_domain_ids_by_permissions =
      resolution
      |> claims()
      |> permitted_domain_ids(interested_permissions)

    {:ok,
     Enum.map(domains, fn %{id: id} = domain ->
       {_, permissions} =
         Enum.reduce(interested_permissions, {0, []}, fn permission, {index, permissions} ->
           if Enum.any?(Enum.at(interested_domain_ids_by_permissions, index), fn x -> x == id end) do
             {index + 1, [permission | permissions]}
           else
             {index + 1, permissions}
           end
         end)

       Map.put(domain, :actions, permissions_to_actions(permissions))
     end)}
  end

  defp with_interested_actions(domains, _args, _resolutions) do
    {:ok, domains}
  end

  def domains(_parent, %{action: action} = args, resolution) do
    {required_permissions, _} = Map.get(@actions_to_permissions, action, {[], []})

    resolution
    |> claims()
    |> permitted_domain_ids(required_permissions)
    |> intersect_domains()
    |> Enum.map(&TaxonomyCache.get_domain/1)
    |> Enum.reject(&is_nil/1)
    |> with_interested_actions(args, resolution)
  end

  def actions(_domain, _args, resolution) do
    resolution
    |> claims()

    {:ok, []}
  end

  defp intersect_domains(domains_by_permission) do
    Enum.reduce(domains_by_permission, fn domains_ids, acc ->
      domains_ids -- domains_ids -- acc
    end)
  end

  defp permitted_domain_ids(%{role: role}, _permissions) when role in ["admin", "service"] do
    [TaxonomyCache.reachable_domain_ids(0)]
  end

  defp permitted_domain_ids(%{role: "user", jti: jti}, permissions) do
    Permissions.permitted_domain_ids(jti, permissions)
  end

  defp permitted_domain_ids(_other, _permissions), do: []

  defp claims(%{context: %{claims: claims}}), do: claims
  defp claims(_), do: nil
end
