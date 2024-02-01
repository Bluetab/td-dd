defmodule TdCx.Auth.CurrentResource do
  @moduledoc """
  A plug to read the current user from Guardian and assign it to the :current_resource
  key in the connection.
  """

  use Plug.Builder

  plug(:current_resource)

  def init(opts), do: opts

  def current_resource(conn, _opts) do
    current_resource = Guardian.Plug.current_resource(conn)
    assign(conn, :current_resource, current_resource)
  end
end