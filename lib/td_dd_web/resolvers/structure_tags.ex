defmodule TdDdWeb.Resolvers.StructureTags do
  @moduledoc """
  Absinthe resolvers for structure tags
  """

  import Canada, only: [can?: 2]

  alias TdDd.DataStructures
  alias TdDd.Utils.ChangesetUtils

  def structure_tags(_parent, args, _resolution) do
    args = Map.put_new(args, :structure_count, true)
    {:ok, DataStructures.list_data_structure_tags(args)}
  end

  def structure_tag(_parent, %{id: id} = _args, _resolution) do
    {:ok, DataStructures.get_data_structure_tag(id: id)}
  end

  def create_structure_tag(_parent, %{structure_tag: params} = _args, _resolution) do
    case DataStructures.create_data_structure_tag(params) do
      {:ok, %{id: id} = _tag} ->
        {:ok, DataStructures.get_data_structure_tag(id: id)}

      {:error, changeset} ->
        {:error, ChangesetUtils.error_message_list_on(changeset)}
    end
  end

  def update_structure_tag(_parent, %{structure_tag: %{id: id} = params} = _args, resolution) do
    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         {:tag, %{} = tag} <- {:tag, DataStructures.get_data_structure_tag(id: id)},
         {:can, true} <- {:can, can?(claims, update(tag))},
         {:ok, _} = reply <- DataStructures.update_data_structure_tag(tag, params) do
      reply
    else
      {:claims, nil} ->
        {:error, :unauthorized}

      {:tag, nil} ->
        {:error, :not_found}

      {:can, false} ->
        {:error, :forbidden}

      {:error, changeset} ->
        {:error, ChangesetUtils.error_message_list_on(changeset)}
    end
  end

  def delete_structure_tag(_parent, %{id: id} = _args, resolution) do
    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         {:tag, %{} = tag} <- {:tag, DataStructures.get_data_structure_tag(id: id)},
         {:can, true} <- {:can, can?(claims, delete(tag))} do
      DataStructures.delete_data_structure_tag(tag)
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:tag, nil} -> {:error, :not_found}
      {:can, false} -> {:error, :forbidden}
    end
  end

  defp claims(%{context: %{claims: claims}}), do: claims
  defp claims(_), do: nil
end
