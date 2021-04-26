defmodule TdDqWeb.PingController do
  use TdDqWeb, :controller

  action_fallback TdDqWeb.FallbackController

  def ping(conn, _params) do
    send_resp(conn, :ok, "pong")
  end
end
