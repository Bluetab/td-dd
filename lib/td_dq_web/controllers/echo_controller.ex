defmodule TdDqWeb.EchoController do
  use TdDqWeb, :controller

  alias Jason, as: JSON

  action_fallback TdDqWeb.FallbackController

  def echo(conn, params) do
    send_resp(conn, 200, params |> JSON.encode!())
  end
end
