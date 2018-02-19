defmodule DataDictionary.Auth.Canary do
  @moduledoc false
  import Plug.Conn

  defp handle(conn) do
    body = Poison.encode!(%{errors: %{detail: "Invalid authorization"}})
    conn
    |> send_resp(403, body)
    |> halt
  end

  def handle_unauthorized(conn) do
    conn
    |> handle()
  end

  def handle_not_found(conn) do
    conn
    |> handle()
  end
end
