defmodule TdDdWeb.Resolvers.Tags do
  @moduledoc """
  Absinthe resolvers for tags
  """

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
         :ok <- Bodyguard.permit(Tags, :update, claims, tag),
         {:ok, _} = reply <- Tags.update_tag(tag, params) do
      reply
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:tag, nil} -> {:error, :not_found}
      {:error, :forbidden} -> {:error, :forbidden}
      {:error, changeset} -> {:error, ChangesetUtils.error_message_list_on(changeset)}
    end
  end

  def delete_tag(_parent, %{id: id} = _args, resolution) do
    with {:claims, %{} = claims} <- {:claims, claims(resolution)},
         {:tag, %{} = tag} <- {:tag, Tags.get_tag(id: id)},
         :ok <- Bodyguard.permit(Tags, :delete, claims, tag) do
      Tags.delete_tag(tag)
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:tag, nil} -> {:error, :not_found}
      {:error, :forbidden} -> {:error, :forbidden}
    end
  end

  defp claims(%{context: %{claims: claims}}), do: claims
  defp claims(_), do: nil
end
