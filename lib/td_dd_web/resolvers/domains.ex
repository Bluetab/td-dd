defmodule TdDdWeb.Resolvers.Domains do
  @moduledoc """
  Absinthe resolvers for domains
  """

  alias TdCache.Permissions
  alias TdCache.TaxonomyCache

  def domains(_parent, %{action: action}, resolution) do
    {:ok, permitted_domains(action, resolution)}
  end

  defp permitted_domains(action, resolution) do
    resolution
    |> claims()
    |> permitted_domain_ids(action)
    |> Enum.map(&TaxonomyCache.get_domain/1)
    |> Enum.reject(&is_nil/1)
  end

  defp permitted_domain_ids(%{role: role}, _action) when role in ["admin", "service"] do
    TaxonomyCache.reachable_domain_ids(0)
  end

  defp permitted_domain_ids(%{role: "user", jti: jti}, "manageTags") do
    Permissions.permitted_domain_ids(jti, :link_data_structure_tag)
  end

  defp permitted_domain_ids(_other, _action), do: []

  defp claims(%{context: %{claims: claims}}), do: claims
  defp claims(_), do: nil
end
