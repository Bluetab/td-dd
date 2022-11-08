defmodule TdDdWeb.Resolvers.Domains do
  @moduledoc """
  Absinthe resolvers for domains
  """

  alias TdCache.Permissions
  alias TdCache.TaxonomyCache
  alias TdDd.Lineage.Units

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
    |> maybe_filter(action)
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

  defp intersection([]), do: []

  defp intersection(domains_by_permission) do
    domains_by_permission
    |> Enum.map(&MapSet.new/1)
    |> Enum.reduce(&MapSet.intersection/2)
  end

  defp permitted_domain_ids(%{role: role}, _action) when role in ["admin", "service"] do
    TaxonomyCache.reachable_domain_ids(0)
  end

  defp permitted_domain_ids(%{role: "user", jti: jti}, "approveGrantRequests"),
    do: Permissions.permitted_domain_ids(jti, :approve_grant_request)

  defp permitted_domain_ids(%{role: "user", jti: jti}, "manageConcept"),
    do: Permissions.permitted_domain_ids(jti, :update_business_concept)

  defp permitted_domain_ids(%{role: "user", jti: jti}, "manageConfiguration"),
    do: Permissions.permitted_domain_ids(jti, :manage_configurations)

  defp permitted_domain_ids(%{role: "user", jti: jti}, "manageImplementations"),
    do: Permissions.permitted_domain_ids(jti, :manage_quality_rule_implementations)

  defp permitted_domain_ids(%{role: "user", jti: jti}, "manageIngest"),
    do: Permissions.permitted_domain_ids(jti, :update_ingest)

  defp permitted_domain_ids(%{role: "user", jti: jti}, "manageNotes"),
    do: Permissions.permitted_domain_ids(jti, :update_data_structure)

  defp permitted_domain_ids(%{role: "user", jti: jti}, "manageRawImplementations"),
    do: Permissions.permitted_domain_ids(jti, :manage_raw_quality_rule_implementations)

  defp permitted_domain_ids(%{role: "user", jti: jti}, "manageRawRulelessImplementations") do
    jti
    |> Permissions.permitted_domain_ids([
      :manage_raw_quality_rule_implementations,
      :manage_ruleless_implementations
    ])
    |> intersection()
  end

  defp permitted_domain_ids(%{role: "user", jti: jti}, "manageRule"),
    do: Permissions.permitted_domain_ids(jti, :manage_quality_rule)

  defp permitted_domain_ids(%{role: "user", jti: jti}, "manageRulelessImplementations") do
    jti
    |> Permissions.permitted_domain_ids([
      :manage_quality_rule_implementations,
      :manage_ruleless_implementations
    ])
    |> intersection()
  end

  defp permitted_domain_ids(%{role: "user", jti: jti}, "manageSource"),
    do: Permissions.permitted_domain_ids(jti, :manage_data_sources)

  defp permitted_domain_ids(%{role: "user", jti: jti}, "manageTags"),
    do: Permissions.permitted_domain_ids(jti, :link_data_structure_tag)

  defp permitted_domain_ids(%{role: "user", jti: jti}, "shareConcept"),
    do: Permissions.permitted_domain_ids(jti, :view_domain)

  defp permitted_domain_ids(%{role: "user", jti: jti}, "createForeignGrantRequest"),
    do: Permissions.permitted_domain_ids(jti, :create_foreign_grant_request)

  defp permitted_domain_ids(%{role: "user", jti: jti}, action_or_permission),
    do: Permissions.permitted_domain_ids(jti, Macro.underscore(action_or_permission))

  defp permitted_domain_ids(_other, _action), do: []

  defp maybe_filter(domain_ids, "viewLineage") do
    with [_ | _] = unit_domain_ids <- Units.list_domain_ids(),
         [_ | _] = reaching_ids <- TaxonomyCache.reaching_domain_ids(unit_domain_ids) do
      intersection([domain_ids, reaching_ids])
    else
      _ -> []
    end
  end

  defp maybe_filter(domain_ids, _action), do: domain_ids

  defp claims(%{context: %{claims: claims}}), do: claims
  defp claims(_), do: nil
end
