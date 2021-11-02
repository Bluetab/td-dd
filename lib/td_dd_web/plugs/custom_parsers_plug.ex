defmodule TdDdWeb.CustomParsersPlug do
  @moduledoc """
    Wrapper for defining `length` configuration in runtime for `Plug.Parsers`
  """
  @behaviour Plug

  @impl true
  def init(_opts) do
    []
  end

  @impl true
  def call(conn, _opts) do
    length =
      :td_dd
      |> Application.get_env(__MODULE__)
      |> Keyword.get(:max_payload_length)

    dynamic_opts =
      Plug.Parsers.init(
        parsers: [:urlencoded, :multipart, :json],
        pass: ["*/*"],
        json_decoder: Jason,
        length: length
      )

    Plug.Parsers.call(conn, dynamic_opts)
  end
end
