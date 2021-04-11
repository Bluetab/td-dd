defmodule TdCxWeb.EchoController do
  use TdCxWeb, :controller

  action_fallback TdCxWeb.FallbackController

  def echo(conn, params) do
    send_resp(conn, 200, params |> Jason.encode!())
  end
end
