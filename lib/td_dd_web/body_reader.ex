defmodule TdDdWeb.BodyReader do
  @moduledoc """
  Custom body reader to allow the maximum payload length to be configured
  dynamically.
  """

  def read_body(conn, opts) do
    Plug.Conn.read_body(conn, opts)
  end

  def max_payload_length do
    :td_dd
    |> Application.get_env(__MODULE__)
    |> Keyword.get(:max_payload_length, 100_000_000)
  end
end
