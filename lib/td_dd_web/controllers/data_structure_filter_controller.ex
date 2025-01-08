defmodule TdDdWeb.DataStructureFilterController do
  require Logger
  use TdDdWeb, :controller

  alias TdDd.DataStructures.Search

  plug(TdDdWeb.SearchPermissionPlug)

  action_fallback(TdDdWeb.FallbackController)

  def index(conn, _params) do
    claims = conn.assigns[:current_resource]
    permission = conn.assigns[:search_permission]
    {:ok, filters} = Search.get_filter_values(claims, permission, %{})
    render(conn, "show.json", filters: filters)
  end

  def search(conn, params) do
    my_grant_requests = Map.get(params, "my_grant_requests")
    claims = conn.assigns[:current_resource]

    permission =
      if my_grant_requests, do: :create_grant_request, else: conn.assigns[:search_permission]

    params = Map.put(params, "without", "deleted_at")
    {:ok, filters} = Search.get_filter_values(claims, permission, params)
    render(conn, "show.json", filters: filters)
  end

  def get_bucket_paths(conn, bucket_filters) do
    claims = conn.assigns[:current_resource]
    permission = conn.assigns[:search_permission]
    bucket_paths = Search.get_bucket_paths(claims, permission, bucket_filters)
    render(conn, "bucket_paths.json", bucket_paths: bucket_paths)
  end
end
