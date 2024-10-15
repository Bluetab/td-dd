defmodule TdDd.I18n.Pipeline.Language do
  @moduledoc """
  Plug pipeline to add locales to conn assings and absinthe context
  """

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> TdCore.I18n.Plug.Language.call([])
    |> Truedat.I18n.Plug.Language.call([])
  end
end
