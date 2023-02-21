defmodule TdDdWeb.Resolvers.Structures do
  @moduledoc """
  Absinthe resolvers for data structures and related entities
  """

  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructureLinks
  alias TdDd.DataStructures.Relations
  alias TdDd.DataStructures.Tags
  alias TdDd.Utils.CollectionUtils

  def data_structures(_parent, args, _resolution) do
    {:ok, DataStructures.list_data_structures(args)}
  end

  def data_structure(_parent, %{id: id} = _args, resolution) do
    with {:claims, claims} when not is_nil(claims) <- {:claims, claims(resolution)},
         {:data_structure, %{} = structure} <-
           {:data_structure, DataStructures.get_data_structure(id)},
         :ok <- Bodyguard.permit(DataStructures, :view_data_structure, claims, structure) do
      {:ok, structure}
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:data_structure, nil} -> {:error, :not_found}
      {:error, :forbidden} -> {:error, :forbidden}
    end
  end

  def data_structure(%{data_structure_id: id}, _args, resolution),
    do: data_structure(%{}, %{id: id}, resolution)

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

  def data_structure_version_path(%{id: id}, _args, _resolution) do
    path =
      id
      |> ds_path
      |> Enum.map(&Map.get(&1, "name"))

    {:ok, path}
  end

  def data_structure_version_path_with_ids(%{id: id}, _args, _resolution) do
    path =
      id
      |> ds_path
      |> Enum.map(&CollectionUtils.atomize_keys(&1))

    {:ok, path}
  end

  defp ds_path(id) do
    [ids: [id]]
    |> DataStructures.enriched_structure_versions()
    |> hd()
    |> Map.get(:path)
  end

  def available_tags(%{} = structure, _args, resolution) do
    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         :ok <- Bodyguard.permit(DataStructures, :tag, claims, structure) do
      {:ok, Tags.list_available_tags(structure)}
    else
      {:claims, nil} -> {:error, :unauthorized}
      _ -> {:ok, []}
    end
  end

  def structure_tags(%{} = data_structure, _args, _resolution) do
    {:ok, Tags.tags(data_structure)}
  end

  def data_structure_links(%{} = data_structure, _args, _resolution) do
    {:ok, DataStructureLinks.links(data_structure)}
  end

  defp claims(%{context: %{claims: claims}}), do: claims
  defp claims(_), do: nil
end
