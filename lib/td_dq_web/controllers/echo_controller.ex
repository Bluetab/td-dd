defmodule TdDqWeb.EchoController do
  use TdDqWeb, :controller

  action_fallback TdDqWeb.FallbackController

  def echo(conn, params) do
    send_resp(conn, 200, params |> Poison.encode!)
  end
end
