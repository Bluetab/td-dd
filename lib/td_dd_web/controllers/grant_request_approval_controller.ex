defmodule TdDdWeb.GrantRequestApprovalController do
  use TdDdWeb, [:controller, :debug]

  action_fallback(TdDdWeb.FallbackController)

  def index(conn, _params) do
    send_resp(conn, 200, "pong")
  end
end
