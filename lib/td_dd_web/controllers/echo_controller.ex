defmodule TdDdWeb.EchoController do
  use TdDdWeb, [:controller, :debug]

  action_fallback(TdDdWeb.FallbackController)

  def echo(conn, params) do
    send_resp(conn, 200, params |> Jason.encode!())
  end
end
