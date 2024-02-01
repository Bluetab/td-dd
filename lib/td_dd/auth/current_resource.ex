defmodule TdDd.Auth.CurrentResource do
  @moduledoc false

  import Guardian.Plug, only: [current_resource: 1]

  alias Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    claims = current_resource(conn)

    conn
    |> Absinthe.Plug.put_options(context: %{claims: claims})
    |> Conn.assign(:current_resource, claims)
  end
end