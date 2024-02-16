defmodule TdDdWeb.GrantsController do
  use TdDdWeb, :controller
  use PhoenixSwagger

  alias TdDd.Grants.BulkLoad

  action_fallback(TdDdWeb.FallbackController)

  swagger_path :update do
    description("Bulk grants")
    produces("application/json")

    parameters do
      bulk_grants(:body, Schema.ref(:BulkGrants), "List of Grants")
    end

    response(200, "OK")
    response(403, "User is not authorized to perform this action")
    response(422, "Error during bulk_grants")
  end

  def update(conn, %{"grants" => grants}) do
    claims = conn.assigns[:current_resource]

    with {:ok, _} <- BulkLoad.bulk_load(claims, grants) do
      send_resp(conn, :ok, "")
    end
  end
end
