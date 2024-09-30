defmodule TdDdWeb.Resolvers.Domains do
  @moduledoc """
  Absinthe resolvers for domains
  """

  alias TdCache.Permissions
  alias TdCache.TaxonomyCache
  alias TdDd.Lineage.NodeQuery
  alias TdDd.Lineage.Units
  alias TdDd.Search.StructureEnricher

  @spec domains(any, any, any) :: {:ok, list}

  def domains(_parent, %{action: action, ids: ids}, resolution) do
    {:ok, permitted_domains(action, resolution, ids)}
  end

  def domains(_parent, %{action: action}, resolution) do
    {:ok, permitted_domains(action, resolution)}
  end

  def domains(_parent, %{ids: ids}, _resolution) do
    get_cache_domains(ids)
  end

  def domains(%{domain_ids: domain_ids}, _args, _resolution) do
    get_cache_domains(domain_ids)
  end

  def domain(_parent, %{id: id}, _resolution) do
    {:ok, TaxonomyCache.get_domain(id)}
  end

  def has_any_domain(_parent, %{action: action}, resolution) do
    {:ok, not Enum.empty?(permitted_domains(action, resolution))}
  end

  def get_parents(%{id: id_parent}, _args, _resolution) do
    {:ok, StructureEnricher.get_domain_parents(id_parent)}
  end

  defp get_cache_domains(domain_ids) do
    domains =
      domain_ids
      |> Enum.map(&TaxonomyCache.get_domain/1)
      |> Enum.reject(&is_nil/1)

    {:ok, domains}
  end

  defp permitted_domains(action, resolution, domain_ids \\ []) do
    resolution
    |> claims()
    |> permitted_domain_ids(action)
    |> maybe_filter(action)
    |> Enum.map(&TaxonomyCache.get_domain/1)
    |> Enum.reject(&is_nil/1)
    |> maybe_filter_by_domain_ids(domain_ids)
  end

  def maybe_filter_by_domain_ids(domains, []), do: domains

  def maybe_filter_by_domain_ids(domains, domain_ids) do
    domain_ids
    |> Enum.map(fn id ->
      String.to_integer(id)
    end)
    |> TaxonomyCache.reachable_domain_ids()
    |> then(
      &Enum.filter(domains, fn %{id: id} ->
        Enum.member?(&1, id)
      end)
    )
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

  defp permitted_domain_ids(%{jti: jti}, "approveGrantRequests"),
    do: Permissions.permitted_domain_ids(jti, :approve_grant_request)

  defp permitted_domain_ids(%{jti: jti}, "manageConcept"),
    do: Permissions.permitted_domain_ids(jti, :update_business_concept)

  defp permitted_domain_ids(%{jti: jti}, "manageConfiguration"),
    do: Permissions.permitted_domain_ids(jti, :manage_configurations)

  defp permitted_domain_ids(%{jti: jti}, "manageImplementations"),
    do: Permissions.permitted_domain_ids(jti, :manage_quality_rule_implementations)

  defp permitted_domain_ids(%{jti: jti}, "manageIngest"),
    do: Permissions.permitted_domain_ids(jti, :update_ingest)

  defp permitted_domain_ids(%{jti: jti}, "manageNotes"),
    do: Permissions.permitted_domain_ids(jti, :update_data_structure)

  defp permitted_domain_ids(%{jti: jti}, "manageRawImplementations"),
    do: Permissions.permitted_domain_ids(jti, :manage_raw_quality_rule_implementations)

  defp permitted_domain_ids(%{jti: jti}, "manageBasicImplementations"),
    do: Permissions.permitted_domain_ids(jti, :manage_basic_implementations)

  defp permitted_domain_ids(%{jti: jti}, "manageBasicRulelessImplementations") do
    jti
    |> Permissions.permitted_domain_ids([
      :manage_basic_implementations,
      :manage_ruleless_implementations
    ])
    |> intersection()
  end

  defp permitted_domain_ids(%{jti: jti}, "manageRawRulelessImplementations") do
    jti
    |> Permissions.permitted_domain_ids([
      :manage_raw_quality_rule_implementations,
      :manage_ruleless_implementations
    ])
    |> intersection()
  end

  defp permitted_domain_ids(%{jti: jti}, "manageLinkedImplementations") do
    jti
    |> Permissions.permitted_domain_ids([
      :manage_quality_rule_implementations,
      :manage_ruleless_implementations,
      :link_implementation_business_concept
    ])
    |> intersection()
  end

  defp permitted_domain_ids(%{jti: jti}, "manageLinkedRawImplementations") do
    jti
    |> Permissions.permitted_domain_ids([
      :manage_raw_quality_rule_implementations,
      :manage_ruleless_implementations,
      :link_implementation_business_concept
    ])
    |> intersection()
  end

  defp permitted_domain_ids(%{jti: jti}, "manageRule"),
    do: Permissions.permitted_domain_ids(jti, :manage_quality_rule)

  defp permitted_domain_ids(%{jti: jti}, "manageRulelessImplementations") do
    jti
    |> Permissions.permitted_domain_ids([
      :manage_quality_rule_implementations,
      :manage_ruleless_implementations
    ])
    |> intersection()
  end

  defp permitted_domain_ids(%{jti: jti}, "manageSource"),
    do: Permissions.permitted_domain_ids(jti, :manage_data_sources)

  defp permitted_domain_ids(%{jti: jti}, "manageTags"),
    do: Permissions.permitted_domain_ids(jti, :link_data_structure_tag)

  defp permitted_domain_ids(%{jti: jti}, "shareConcept"),
    do: Permissions.permitted_domain_ids(jti, :view_domain)

  defp permitted_domain_ids(%{jti: jti}, "createForeignGrantRequest"),
    do: Permissions.permitted_domain_ids(jti, :create_foreign_grant_request)

  defp permitted_domain_ids(%{jti: jti}, "createQualityControls"),
    do: Permissions.permitted_domain_ids(jti, :create_quality_controls)

  defp permitted_domain_ids(%{jti: jti}, "publishQualityControls"),
    do: Permissions.permitted_domain_ids(jti, :publish_quality_controls)

  defp permitted_domain_ids(%{jti: jti}, action_or_permission) do
    Permissions.permitted_domain_ids(jti, Macro.underscore(action_or_permission))
  end

  defp permitted_domain_ids(_other, _action), do: []

  defp maybe_filter(domain_ids, "viewLineage") do
    with [_ | _] = unit_domain_ids <- Units.list_domain_ids(),
         structure_domain_ids <- NodeQuery.list_structure_domain_ids(),
         [_ | _] = reaching_ids <-
           TaxonomyCache.reaching_domain_ids(unit_domain_ids ++ structure_domain_ids) do
      intersection([domain_ids, reaching_ids])
    else
      _ -> []
    end
  end

  defp maybe_filter(domain_ids, _action), do: domain_ids

  defp claims(%{context: %{claims: claims}}), do: claims
  defp claims(_), do: nil
end
