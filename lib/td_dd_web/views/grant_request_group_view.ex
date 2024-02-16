defmodule TdDdWeb.GrantRequestGroupView do
  use TdDdWeb, :view

  alias TdDdWeb.GrantRequestGroupView
  alias TdDdWeb.GrantRequestView
  alias TdDdWeb.GrantView
  alias TdDdWeb.UserView

  def render("index.json", %{grant_request_groups: groups}) do
    %{data: render_many(groups, GrantRequestGroupView, "grant_request_group.json")}
  end

  def render("show.json", %{grant_request_group: group}) do
    %{data: render_one(group, GrantRequestGroupView, "grant_request_group.json")}
  end

  def render("grant_request_group.json", %{grant_request_group: group}) do
    group
    |> Map.take([:id, :inserted_at, :user_id, :type, :created_by_id])
    |> put_embeddings(group)
  end

  def render("embedded.json", %{grant_request_group: group}) do
    group
    |> Map.take([:id, :type, :created_by_id])
    |> put_embeddings(group)
  end

  defp put_embeddings(%{} = resp, group) do
    case embeddings(group) do
      map when map == %{} -> resp
      embeddings -> Map.put(resp, :_embedded, embeddings)
    end
  end

  defp embeddings(%{} = group) do
    group
    |> Map.take([:user, :requests, :modification_grant, :created_by])
    |> Enum.reduce(%{}, fn
      {:user, %{} = user}, acc ->
        Map.put(acc, :user, render_one(user, UserView, "embedded.json"))

      {:created_by, %{} = created_by}, acc ->
        Map.put(acc, :created_by, render_one(created_by, UserView, "embedded.json"))

      {:requests, requests}, acc when is_list(requests) ->
        Map.put(
          acc,
          :requests,
          render_many(requests, GrantRequestView, "embedded.json", %{embed: [:data_structure]})
        )

      {:modification_grant, %{} = grant}, acc ->
        Map.put(acc, :modification_grant, render_one(grant, GrantView, "grant.json"))

      _, acc ->
        acc
    end)
  end
end
