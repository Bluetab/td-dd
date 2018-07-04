defmodule TdDdWeb.PingController do
  use TdDdWeb, :controller

  action_fallback TdDdWeb.FallbackController

  def ping(conn, _params) do
    send_resp(conn, 200, "pong")
  end
end
