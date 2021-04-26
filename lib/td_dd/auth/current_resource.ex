defmodule TdDd.Auth.CurrentResource do
  @moduledoc false

  import Guardian.Plug, only: [current_resource: 1]

  alias Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    current_resource = current_resource(conn)
    Conn.assign(conn, :current_resource, current_resource)
  end
end
