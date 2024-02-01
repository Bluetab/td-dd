defmodule TdDq.Auth.Plug.CurrentResource do
  @moduledoc """
  A plug to read the current resource from Guardian and assign it to the :current_resource
  key in the connection.
  """

  use Plug.Builder
  alias Guardian.Plug, as: GuardianPlug

  plug(:current_resource)

  def init(opts), do: opts

  def current_resource(conn, _opts) do
    current_resource = GuardianPlug.current_resource(conn)
    conn |> assign(:current_resource, current_resource)
  end
end