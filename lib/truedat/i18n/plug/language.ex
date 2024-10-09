defmodule Truedat.I18n.Plug.Language do
  @moduledoc """
  A plug to add lang to absinthe context
  """

  def init(opts), do: opts

  def call(conn, _opts) do
    lang = conn.assigns[:locale]
    Absinthe.Plug.assign_context(conn, lang: lang)
  end
end
