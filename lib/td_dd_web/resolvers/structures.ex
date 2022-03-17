defmodule TdDdWeb.Resolvers.Structures do
  @moduledoc """
  Absinthe resolvers for data structures and related entities
  """

  alias TdCache.TaxonomyCache
  alias TdDd.DataStructures

  def data_structure_versions(_parent, args, _resolution) do
    {:ok, DataStructures.list_data_structure_versions(args)}
  end

  def domain_id(%{domain_ids: domain_ids}, _args, _resolution) do
    domain_id =
      case domain_ids do
        [domain_id | _] -> domain_id
        _ -> nil
      end

    {:ok, domain_id}
  end

  def domains(%{domain_ids: domain_ids}, _args, _resolution) do
    domains = domain_ids
    |> Enum.map(&TaxonomyCache.get_domain/1)
    |> Enum.reject(&is_nil/1)

    {:ok, domains}
  end

  def data_structure_version_path(%{id: _id} = dsv, _args, _resolution) do
    path = dsv
    |> DataStructures.get_ancestors()
    |> Enum.map(&(Map.get(&1, :name)))
    {:ok, path}
  end

end
