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
    required_permissions =  Map.get(@actions_to_permissions, action, [])

    {:ok,
     resolution
     |> claims()
     |> permitted_domain_ids(required_permissions)
     |> intersect_domains()
     |> Enum.map(&TaxonomyCache.get_domain/1)
     |> Enum.reject(&is_nil/1)}
  end

  def fetch_permission_domains({:actions, %{actions: actions}}, domains, %{claims: claims}) do
    actions_permissions = Map.take(@actions_to_permissions, actions)

    domains_by_permission =
      actions_permissions
      |> Map.values()
      |> List.flatten()
      |> Enum.uniq()
      |> then(&(Enum.zip(&1, permitted_domain_ids(claims, &1))))
      |> Map.new()


    domains_by_actions =
      Enum.map(actions_permissions, fn {key, value} ->
        domains =
          value
          |> Enum.map(fn permission -> domains_by_permission[permission] end)
          |> intersect_domains()

        {key, domains}
      end)
      |> Map.new()

    domains
    |> Map.new(&{&1, actions_by_domain(&1, domains_by_actions)})
  end


  defp actions_by_domain(%{id: domain_id}, permitted_domains_by_actions) do
    Enum.reduce(permitted_domains_by_actions, [], fn {action, domain_ids}, acc ->
      if Enum.any?(domain_ids, fn id -> id == domain_id end) do
        [action | acc]
      else
        acc
      end
    end)
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
