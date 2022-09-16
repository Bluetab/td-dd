defmodule TdDdWeb.Resolvers.Me do
  @moduledoc """
  Absinthe resolvers for current user related entities
  """

  def me(_parent, _args, resolution) do
    case claims(resolution) do
      %{user_id: id, user_name: name} -> {:ok, %{id: id, user_name: name}}
      _ -> {:error, :forbidden}
    end
  end

  defp claims(%{context: %{claims: claims}}), do: claims
  defp claims(_), do: nil
end
