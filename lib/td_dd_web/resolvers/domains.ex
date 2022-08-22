defmodule TdDdWeb.Resolvers.Domains do
  @moduledoc """
  Absinthe resolvers for domains
  """

  alias TdCache.Permissions
  alias TdCache.TaxonomyCache

  @actions_to_permissions %{
    "manageConcepts" => [:update_business_concept],
    "manageTags" => [:link_data_structure_tag],
    "manageImplementations" => [:manage_quality_rule_implementations],
    "manageRawImplementations" => [:manage_raw_quality_rule_implementations],
    "manageRulelessImplementations" => [
      :manage_quality_rule_implementations,
      :manage_ruleless_implementations
    ],
    "manageRawRulelessImplementations" => [
      :manage_raw_quality_rule_implementations,
      :manage_ruleless_implementations
    ],
    "publishImplementation" => [:publish_implementation],
    "manageSegments" => [:manage_segments]
  }

  def domains(_parent, %{action: action}, resolution) do
    {:ok, permitted_domains(action, resolution)}
  end

  def domains(_parent, %{ids: ids}, _resolution) do
    domains =
      ids
      |> Enum.map(&TaxonomyCache.get_domain/1)
      |> Enum.reject(&is_nil/1)

    {:ok, domains}
  end

  def domain(_parent, %{id: id}, _resolution) do
    {:ok, TaxonomyCache.get_domain(id)}
  end

  defp permitted_domains(action, resolution) do
    resolution
    |> claims()
    |> permitted_domain_ids(action)
    |> Enum.map(&TaxonomyCache.get_domain/1)
    |> Enum.reject(&is_nil/1)
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

  defp intersect_domains([]), do: []

  defp intersect_domains(domains_by_permission) do
    domains_by_permission
    |> Enum.map(&MapSet.new/1)
    |> Enum.reduce(&MapSet.intersection/2)
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
