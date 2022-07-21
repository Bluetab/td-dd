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
    ]
  }

  def domains(_parent, %{action: action}, resolution) do
    {:ok, permitted_domains(action, resolution)}
  end

  def actions(_domain, _args, resolution) do
    # debemos obtener la lista de dominios para los que se puede ejecutar cada una de las acciones (de manera independiente)
    # el cabrón de guille tenía razón… mejor hacer la petición a cache, éste NO hace el AND, y así en DD se puede usar AND/OR, según se quiera
    # en este caso queremos conocer de manera independiente si existe el dominio actual en la lista de dominios de publish_implementation y de manage_segments
    # jummm… cambio de idea… realmente tenemos la posibilidad de ejecutar un hasPermissions(action, domain) para el resolver por cada dominio…
    # Para ser eficiente deberíamos poder hacer la petición de todos los permisos/dominios que busquemos a caché una vez antes de empezar con los resolvers
    # y reutilizar la información para cada uno de los dominios sin tener que relanzar la llamada a cache…
    actions = ["publish_implementation", "manage_segment"]

    resolution
    |> claims()
    |> permitted_domain_ids(actions)
    |> IO.inspect(label: " actions -->")
  end

  ## acciones de filtrado
  ## acciones de permisos
  defp permitted_domains(action, resolution) do
    resolution
    |> claims()
    |> permitted_domain_ids(action)
    |> IO.inspect(label: " permitted ->")
    |> Enum.map(&TaxonomyCache.get_domain/1)
    |> Enum.reject(&is_nil/1)
  end

  defp permitted_domain_ids(%{role: role}, _action) when role in ["admin", "service"] do
    TaxonomyCache.reachable_domain_ids(0)
  end

  defp permitted_domain_ids(%{role: "user", jti: jti}, action) do
    Permissions.permitted_domain_ids(jti, Map.get(@actions_to_permissions, action))
    |> IO.inspect(label: "permitted_domain_ids ->")
  end

  defp permitted_domain_ids(_other, _action), do: []

  defp claims(%{context: %{claims: claims}}), do: claims
  defp claims(_), do: nil
end
