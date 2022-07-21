defmodule TdDdWeb.Resolvers.Structures do
  @moduledoc """
  Absinthe resolvers for data structures and related entities
  """

  import Canada, only: [can?: 2]

  alias TdCache.TaxonomyCache
  alias TdDd.DataStructures
  alias TdDd.DataStructures.Relations
  alias TdDd.DataStructures.Tags

  def data_structures(_parent, args, _resolution) do
    {:ok, DataStructures.list_data_structures(args)}
  end

  def data_structure(_parent, %{id: id} = _args, resolution) do
    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         {:data_structure, %{} = structure} <-
           {:data_structure, DataStructures.get_data_structure(id)},
         {:can, true} <- {:can, can?(claims, view_data_structure(structure))} do
      {:ok, structure}
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:data_structure, nil} -> {:error, :not_found}
      {:can, false} -> {:error, :forbidden}
    end
  end

  def data_structure_versions(_parent, args, _resolution) do
    {:ok, DataStructures.list_data_structure_versions(args)}
  end

  def data_structure_relations(_parent, args, _resolution) do
    {:ok, Relations.list_data_structure_relations(args)}
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
    domains =
      domain_ids
      |> Enum.map(&TaxonomyCache.get_domain/1)
      |> Enum.reject(&is_nil/1)

    {:ok, domains}
  end

  def data_structure_version_path(%{id: id}, _args, _resolution) do
    path =
      [ids: [id]]
      |> DataStructures.enriched_structure_versions()
      |> hd()
      |> Map.get(:path)
      |> Enum.map(&Map.get(&1, "name"))

    {:ok, path}
  end

  def available_tags(%{} = structure, _args, resolution) do
    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         {:can, true} <- {:can, can?(claims, tag(structure))} do
      {:ok, Tags.list_available_tags(structure)}
    else
      {:claims, nil} -> {:error, :unauthorized}
      _ -> {:ok, []}
    end
  end

  def structure_tags(%{} = data_structure, _args, _resolution) do
    {:ok, Tags.tags(data_structure)}
  end

  defp claims(%{context: %{claims: claims}}), do: claims
  defp claims(_), do: nil
end
