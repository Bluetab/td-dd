defmodule TdDdWeb.DataStructureLinkController do
  use TdDdWeb, :controller
  use TdHypermedia, :controller
  use PhoenixSwagger

  alias TdDdWeb.ErrorView

  require Logger

  action_fallback(TdDdWeb.FallbackController)

  swagger_path :create_link do
    description("Creates a Link")
    produces("application/json")

    response(202, "Accepted")
  end

  def create_link(conn, _params) do
    # This method is only used to generate an action in the data structure hypermedia response
    send_resp(conn, :accepted, "")
  end
end
