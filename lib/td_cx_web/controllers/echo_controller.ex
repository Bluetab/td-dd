defmodule TdCxWeb.PingController do
  use TdCxWeb, :controller

  action_fallback TdCxWeb.FallbackController

  def ping(conn, _params) do
    send_resp(conn, 200, "pong")
  end
end
