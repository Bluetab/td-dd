defmodule TdDdWeb.Resolvers.GrantRequests do
  @moduledoc """
  Absinthe resolvers for grant requests
  """

  import Canada, only: [can?: 2]

  alias TdDd.Grants
  alias TdDd.Grants.Requests

  def latest_grant_request(_parent, %{data_structure_id: data_structure_id}, resolution) do
    with {:claims, %{user_id: user_id} = claims} <- {:claims, claims(resolution)},
         {:grant_request, grant_request} <-
           {:grant_request,
            Requests.get_grant_request_by_data_structure(data_structure_id, user_id)},
         {:can, true} <- {:can, can_view_grant_request(claims, grant_request)} do
      {:ok, grant_request}
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:can, false} -> {:error, :forbidden}
      {:error, :grant_request, changeset, _} -> {:error, changeset}
    end
  end

  defp can_view_grant_request(_, nil), do: true

  defp can_view_grant_request(claims, grant_request), do: can?(claims, list(grant_request))

  def group(grant_request, _args, _resolution) do
    {:ok, Requests.get_group(grant_request)}
  end

  def status(grant_request, _args, _resolution) do
    {:ok, Requests.get_status(grant_request)}
  end

  def grant(%{modification_grant_id: nil}, _args, _resolution) do
    {:ok, nil}
  end

  def grant(%{modification_grant_id: grant_id}, _args, _resolution) do
    {:ok, Grants.get_grant!(grant_id)}
  end

  defp claims(%{context: %{claims: claims}}), do: claims
  defp claims(_), do: nil
end
