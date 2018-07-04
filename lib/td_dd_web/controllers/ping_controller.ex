defmodule TdDdWeb.EchoController do
  use TdDdWeb, :controller

  action_fallback TdDdWeb.FallbackController

  def echo(conn, params) do
    send_resp(conn, 200, params |> Poison.encode!)
  end
end
