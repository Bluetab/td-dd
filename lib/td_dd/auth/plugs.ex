defmodule TdDd.Auth.Plugs do
  @moduledoc false
  import Plug.Conn

  def load_canary_action(conn, opts) do
    phoenix_action = opts[:phoenix_action]
      || raise "load_canary_action: phoenix_action not defined"
    canary_action  = opts[:canary_action]
      || raise "load_canary_action: canary_action not defined"

    case conn.private.phoenix_action do
      ^phoenix_action ->
        conn
        |> assign(:canary_action, canary_action)
      _ -> conn
    end
  end
end
