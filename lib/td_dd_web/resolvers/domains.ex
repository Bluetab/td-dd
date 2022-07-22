defmodule TdDdWeb.Resolvers.Domains do
  @moduledoc """
  Absinthe resolvers for domains
  """

  alias TdCache.Permissions
  alias TdCache.TaxonomyCache

  @interesting_permissions %{
    "manage_implementations" => [:publish_implementation, :manage_segments]
  }
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
    ]
  }

  # TODO CHECK!!!!!
  # retrieved_permissions
  # Map.values(@actions_to_permissions) |> Enum.map(fn(permissions) -> permissions -- retrieved_permissions == [] :ok :rejectend)

  def domains(_parent, %{action: action}, resolution) do
    domains =
      resolution
      |> claims()
      |> permitted_domain_ids(Map.get(@actions_to_permissions, action))
      |> intersect_domains()
      |> Enum.map(&TaxonomyCache.get_domain/1)
      |> Enum.reject(&is_nil/1)

    optional_domain_ids_by_permissions =
      resolution
      |> claims()
      |> permitted_domain_ids(Map.get(@interesting_permissions, action))

    domains =
      Enum.map(domains, fn %{id: id} = domain ->
        {_, permissions} =
          Enum.reduce(Map.get(@interesting_permissions, action, []), {0, []}, fn permission,
                                                                                 {index,
                                                                                  permissions} ->
            if Enum.any?(Enum.at(optional_domain_ids_by_permissions, index), fn x -> x == id end) do
              {index + 1, [permission | permissions]}
            else
              {index + 1, permissions}
            end
          end)

        Map.put(domain, :actions, permissions)
      end)

    {:ok, domains}
  end

  def actions(_domain, _args, resolution) do
    # debemos obtener la lista de dominios para los que se puede ejecutar cada una de las acciones (de manera independiente)
    # el cabrón de guille tenía razón… mejor hacer la petición a cache, éste NO hace el AND, y así en DD se puede usar AND/OR, según se quiera
    # en este caso queremos conocer de manera independiente si existe el dominio actual en la lista de dominios de publish_implementation y de manage_segments
    # jummm… cambio de idea… realmente tenemos la posibilidad de ejecutar un hasPermissions(action, domain) para el resolver por cada dominio…
    # Para ser eficiente deberíamos poder hacer la petición de todos los permisos/dominios que busquemos a caché una vez antes de empezar con los resolvers
    # y reutilizar la información para cada uno de los dominios sin tener que relanzar la llamada a cache…
    # actions = ["publish_implementation", "manage_segment"]

    resolution
    |> claims()

    # |> permitted_domain_ids(actions)
    # |> IO.inspect(label: " actions -->")
    {:ok, []}
  end

  ## acciones de filtrado
  ## acciones de permisos
  defp permitted_domains(action, resolution) do
    resolution
    |> claims()
    |> permitted_domain_ids(action)
    |> Enum.map(&TaxonomyCache.get_domain/1)
    |> Enum.reject(&is_nil/1)
  end

  defp intersect_domains(domains_by_permission) do
    IO.inspect(domains_by_permission, label: "DOMAINS_BY_PERMISSIONS")

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
