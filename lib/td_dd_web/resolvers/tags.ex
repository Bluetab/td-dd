defmodule TdDdWeb.Resolvers.Tags do
  @moduledoc """
  Absinthe resolvers for tags
  """

  import Canada, only: [can?: 2]

  alias TdDd.DataStructures.Tags
  alias TdDd.Utils.ChangesetUtils

  def tags(_parent, args, _resolution) do
    args = Map.put_new(args, :structure_count, true)
    {:ok, Tags.list_tags(args)}
  end

  def tag(_parent, %{id: id} = _args, _resolution) do
    {:ok, Tags.get_tag(id: id)}
  end

  def create_tag(_parent, %{tag: params} = _args, _resolution) do
    case Tags.create_tag(params) do
      {:ok, %{id: id} = _tag} ->
        {:ok, Tags.get_tag(id: id)}

      {:error, changeset} ->
        {:error, ChangesetUtils.error_message_list_on(changeset)}
    end
  end

  def update_tag(_parent, %{tag: %{id: id} = params} = _args, resolution) do
    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         {:tag, %{} = tag} <- {:tag, Tags.get_tag(id: id)},
         {:can, true} <- {:can, can?(claims, update(tag))},
         {:ok, _} = reply <- Tags.update_tag(tag, params) do
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

  def delete_tag(_parent, %{id: id} = _args, resolution) do
    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         {:tag, %{} = tag} <- {:tag, Tags.get_tag(id: id)},
         {:can, true} <- {:can, can?(claims, delete(tag))} do
      Tags.delete_tag(tag)
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:tag, nil} -> {:error, :not_found}
      {:can, false} -> {:error, :forbidden}
    end
  end

  defp claims(%{context: %{claims: claims}}), do: claims
  defp claims(_), do: nil
end
