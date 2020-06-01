defmodule TdDd.Auth.CurrentUser do
  @moduledoc false

  import Guardian.Plug, only: [current_resource: 1]

  alias Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    current_user = current_resource(conn)
    Conn.assign(conn, :current_user, current_user)
  end
end
