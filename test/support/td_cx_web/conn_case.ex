defmodule TdCxWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate

  import AuthenticationSupport, only: :functions

  alias Ecto.Adapters.SQL.Sandbox
  alias Phoenix.ConnTest

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import TdDd.Factory

      alias TdCxWeb.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint TdCxWeb.Endpoint
    end
  end

  setup tags do
    :ok = Sandbox.checkout(TdDd.Repo)

    unless tags[:async] do
      Sandbox.mode(TdDd.Repo, {:shared, self()})
    end

    case tags[:authentication] do
      nil ->
        [conn: ConnTest.build_conn()]

      auth_opts ->
        auth_opts
        |> create_claims()
        |> create_user_auth_conn()
        |> assign_permissions(auth_opts[:permissions])
    end
  end
end
