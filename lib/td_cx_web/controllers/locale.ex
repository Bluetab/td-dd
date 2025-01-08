defmodule TdCxWeb.Locale do
  import Plug.Conn

  @moduledoc """
    Sets locale retrieved from requests in session
  """

  def init(_opts), do: nil

  def call(conn, _opts) do
    case conn.params["locale"] || conn |> fetch_session |> get_session(:locale) do
      nil ->
        conn

      locale ->
        conn
        |> fetch_session
        |> put_session(:locale, locale)
    end
  end
end
