defmodule TdDdWeb.GrantRequestGroupView do
  use TdDdWeb, :view

  alias TdDdWeb.GrantRequestGroupView
  alias TdDdWeb.GrantRequestView

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
    |> with_requests(grant_request_group)
  end

  defp with_requests(json, %{requests: requests}) when is_list(requests),
    do: Map.put(json, :requests, render_many(requests, GrantRequestView, "grant_request.json"))

  defp with_requests(json, _), do: json
end
