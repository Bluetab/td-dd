defmodule TdDq.Auth.ErrorHandler do
  @moduledoc false
  import Plug.Conn

  def auth_error(conn, {type, _reason}, _opts) do
    body = Jason.encode!(%{message: to_string(type)})
    send_resp(conn, :unauthorized, body)
  end
end