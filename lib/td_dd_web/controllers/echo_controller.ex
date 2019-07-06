defmodule TdDdWeb.EchoController do
  use TdDdWeb, [:controller, :warn]

  alias Jason, as: JSON

  action_fallback(TdDdWeb.FallbackController)

  def echo(conn, params) do
    send_resp(conn, 200, params |> JSON.encode!())
  end
end
