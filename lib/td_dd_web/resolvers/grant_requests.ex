defmodule TdDdWeb.Resolvers.GrantRequests do
  @moduledoc """
  Absinthe resolvers for grant requests
  """

  alias TdDd.Grants
  alias TdDd.Grants.Requests

  def latest_grant_request(_parent, args, resolution) do
    with {:claims, %{user_id: user_id} = claims} <- {:claims, claims(resolution)},
         {:grant_request, %{} = grant_request} <-
           {:grant_request, Requests.latest_grant_request(args, user_id)},
         :ok <- Bodyguard.permit(Requests, :view, claims, grant_request) do
      {:ok, grant_request}
    else
      {:claims, nil} -> {:error, :unauthorized}
      {:error, :forbidden} -> {:error, :forbidden}
      {:grant_request, changeset} -> {:error, changeset}
    end
  end

  def group(grant_request, _args, _resolution) do
    {:ok, Requests.get_group(grant_request)}
  end

  def status(grant_request, _args, _resolution) do
    {:ok, Requests.latest_grant_request_status(grant_request)}
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
