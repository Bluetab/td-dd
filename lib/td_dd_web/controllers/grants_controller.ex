defmodule TdDdWeb.GrantsController do
  use TdDdWeb, :controller

  alias TdDd.Grants.BulkLoad

  action_fallback(TdDdWeb.FallbackController)

  def update(conn, %{"grants" => grants}) do
    claims = conn.assigns[:current_resource]

    with {:ok, _} <- BulkLoad.bulk_load(claims, grants) do
      send_resp(conn, :ok, "")
    end
  end
end
