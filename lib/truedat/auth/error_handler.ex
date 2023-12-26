defmodule Truedat.Auth.ErrorHandler do
  @moduledoc false
  import Plug.Conn

  def unauthorized(conn) do
    conn
    |> auth_error({:unauthorized, nil})
    |> halt()
  end

  def auth_error(conn, {type, _reason}, _opts \\ []) do
    body = Jason.encode!(%{message: to_string(type)})

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(:unauthorized, body)
  end
end
