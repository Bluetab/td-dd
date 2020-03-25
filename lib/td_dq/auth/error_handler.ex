defmodule TdDq.Auth.ErrorHandler do
  @moduledoc false
  import Plug.Conn

  alias Jason, as: JSON

  def auth_error(conn, {type, _reason}, _opts) do
    body = JSON.encode!(%{message: to_string(type)})
    send_resp(conn, :unauthorized, body)
  end
end
