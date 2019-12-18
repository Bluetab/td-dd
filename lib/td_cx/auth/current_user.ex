defmodule TdCx.Auth.CurrentUser do
  @moduledoc """
  A plug to read the current user from Guardian and assign it to the :current_user
  key in the connection.
  """

  use Plug.Builder
  alias Guardian.Plug, as: GuardianPlug

  plug(:current_user)

  def init(opts), do: opts

  def current_user(conn, _opts) do
    current_user = GuardianPlug.current_resource(conn)

    conn |> assign(:current_user, current_user)
  end

end
