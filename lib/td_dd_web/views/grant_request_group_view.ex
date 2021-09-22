defmodule TdDdWeb.GrantRequestGroupView do
  use TdDdWeb, :view

  alias TdDdWeb.GrantRequestGroupView
  alias TdDdWeb.GrantRequestView
  alias TdDdWeb.UserView

  def render("index.json", %{grant_request_groups: grant_request_groups}) do
    %{data: render_many(grant_request_groups, GrantRequestGroupView, "grant_request_group.json")}
  end

  def render("show.json", %{grant_request_group: grant_request_group}) do
    %{data: render_one(grant_request_group, GrantRequestGroupView, "grant_request_group.json")}
  end

  def render("grant_request_group.json", %{grant_request_group: grant_request_group}) do
    %{
      id: grant_request_group.id,
      inserted_at: grant_request_group.inserted_at,
      user_id: grant_request_group.user_id,
      type: grant_request_group.type
    }
    |> put_embeddings(grant_request_group)
  end

  def render("embedded.json", %{grant_request_group: group}) do
    group
    |> Map.take([:id, :type])
    |> put_embeddings(group)
  end

  defp put_embeddings(%{} = resp, grant_request_group) do
    case embeddings(grant_request_group) do
      map when map == %{} -> resp
      embeddings -> Map.put(resp, :_embedded, embeddings)
    end
  end

  defp embeddings(%{} = grant_request_group) do
    grant_request_group
    |> Map.take([:user, :requests])
    |> Enum.reduce(%{}, fn
      {:user, %{} = user}, acc ->
        Map.put(acc, :user, render_one(user, UserView, "embedded.json"))

      {:requests, requests}, acc when is_list(requests) ->
        Map.put(
          acc,
          :requests,
          render_many(requests, GrantRequestView, "embedded.json", %{embed: [:data_structure]})
        )

      _, acc ->
        acc
    end)
  end
end
