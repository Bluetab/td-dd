defmodule Truedat.Auth.Plug.CurrentResource do
  @moduledoc """
  A plug to assign claims to the :current_resource key in the connection and to
  the :claims key in the Absinthe context
  """

  def init(opts), do: opts

  def call(conn, _opts) do
    claims = Guardian.Plug.current_resource(conn)

    conn
    |> Absinthe.Plug.put_options(context: %{claims: claims})
    |> Plug.Conn.assign(:current_resource, claims)
  end
end
