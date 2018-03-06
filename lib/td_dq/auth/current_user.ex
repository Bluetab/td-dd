defmodule TdDQ.Auth.Plug.CurrentUser do
  @moduledoc false

  alias Guardian.Plug, as: GuardianPlug
  alias Plug.Conn, as: PlugConn

  def init(opts), do: opts

  def call(conn, _opts) do
    current_user = GuardianPlug.current_resource(conn)
    PlugConn.assign(conn, :current_user, current_user)
  end
end
