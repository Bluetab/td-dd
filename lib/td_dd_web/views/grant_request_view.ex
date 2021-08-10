defmodule TdDdWeb.GrantRequestView do
  use TdDdWeb, :view
  alias TdDdWeb.GrantRequestView

  def render("index.json", %{grant_requests: grant_requests}) do
    %{data: render_many(grant_requests, GrantRequestView, "grant_request.json")}
  end

  def render("show.json", %{grant_request: grant_request}) do
    %{data: render_one(grant_request, GrantRequestView, "grant_request.json")}
  end

  def render("grant_request.json", %{grant_request: grant_request}) do
    %{
      id: grant_request.id,
      filters: grant_request.filters,
      metadata: grant_request.metadata,
      data_structure_id: grant_request.data_structure_id
    }
  end
end
