defmodule TdDdWeb.Resolvers.Domains do
  @moduledoc """
  Absinthe resolvers for domains
  """

  alias TdCache.Permissions
  alias TdCache.TaxonomyCache

  @actions_to_permissions %{
    "manage_tags" => [:link_data_structure_tag],
    "manage_implementations" => [:manage_quality_rule_implementations],
    "manage_raw_implementations" => [:manage_raw_quality_rule_implementations],
    "manage_ruleless_implementations" => [
      :manage_quality_rule_implementations,
      :manage_ruleless_implementations
    ],
    "manage_raw_ruleless_implementations" => [
      :manage_raw_quality_rule_implementations,
      :manage_ruleless_implementations
    ],
    "publish_implementation" => [:publish_implementation],
    "manage_segments" => [:manage_segments]
  }

  def domains(_parent, %{action: action}, resolution) do
    {:ok,
     resolution
     |> claims()
     |> permitted_domain_ids(action)
     |> Enum.map(&TaxonomyCache.get_domain/1)
     |> Enum.reject(&is_nil/1)}
  end

  def fetch_permission_domains({:actions, %{actions: actions}}, domains, %{claims: claims}) do
    domains_by_actions =
      Map.new(actions, fn action -> {action, permitted_domain_ids(claims, action)} end)

    Map.new(domains, &{&1, actions_by_domain(&1, domains_by_actions)})
  end

  defp actions_by_domain(%{id: domain_id}, permitted_domains_by_actions) do
    Enum.reduce(permitted_domains_by_actions, [], fn {action, domain_ids}, acc ->
      has_any = Enum.any?(domain_ids, fn id -> id == domain_id end)
      if has_any, do: [action | acc], else: acc
    end)
  end

  defp intersect_domains(domains_by_permission) do
    Enum.reduce(domains_by_permission, fn domains_ids, acc ->
      domains_ids -- domains_ids -- acc
    end)
  end

  defp permitted_domain_ids(%{role: "user", jti: jti}, action) do
    jti
    |> Permissions.permitted_domain_ids(Map.get(@actions_to_permissions, action, []))
    |> intersect_domains()
  end

  defp permitted_domain_ids(%{role: role}, _action) when role in ["admin", "service"] do
    TaxonomyCache.reachable_domain_ids(0)
  end

  defp permitted_domain_ids(_other, _action), do: []

  defp claims(%{context: %{claims: claims}}), do: claims
  defp claims(_), do: nil
end
