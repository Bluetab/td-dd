defmodule TdDdWeb.Resolvers.StructureTags do
  @moduledoc """
  Absinthe resolvers for data structure tags
  """

  import Canada, only: [can?: 2]

  alias TdDd.DataStructures
  alias TdDd.DataStructures.Tags

  def tag_structure(
        _parent,
        %{structure_tag: %{data_structure_id: structure_id, tag_id: tag_id} = args},
        resolution
      ) do
    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         {:struct, %{} = structure} <- {:struct, DataStructures.get_data_structure(structure_id)},
         {:tag, %{} = tag} <- {:tag, Tags.get_tag(id: tag_id)},
         {:can, true} <- {:can, can?(claims, tag(structure))},
         {:ok, %{structure_tag: %{} = structure_tag}} <-
           Tags.tag_structure(structure, tag, args, claims) do
      {:ok, structure_tag}
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:struct, nil} -> {:error, :not_found}
      {:tag, nil} -> {:error, :not_found}
      {:can, false} -> {:error, :forbidden}
      {:error, _, changeset, _} -> {:error, changeset}
    end
  end

  def delete_structure_tag(_parent, %{id: id} = _args, resolution) do
    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         {:structure_tag, %{} = structure_tag} <- {:structure_tag, Tags.get_structure_tag(id)},
         {:can, true} <- {:can, can?(claims, delete(structure_tag))},
         {:ok, %{structure_tag: %{} = structure_tag}} <-
           Tags.delete_structure_tag(structure_tag, claims) do
      {:ok, structure_tag}
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:structure_tag, nil} -> {:error, :not_found}
      {:can, false} -> {:error, :forbidden}
      {:error, _, changeset, _} -> {:error, changeset}
    end
  end

  defp claims(%{context: %{claims: claims}}), do: claims
  defp claims(_), do: nil
end
