defmodule TdCxWeb.EchoController do
  use TdCxWeb, :controller

  alias Jason, as: JSON

  action_fallback TdCxWeb.FallbackController

  def echo(conn, params) do
    send_resp(conn, 200, params |> JSON.encode!())
  end
end
