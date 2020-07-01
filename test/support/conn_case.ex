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
  import TdCxWeb.Authentication, only: :functions
  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import TdCx.Factory

      alias TdCxWeb.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint TdCxWeb.Endpoint
    end
  end

  @admin_user_name "app-admin"

  setup tags do
    :ok = Sandbox.checkout(TdCx.Repo)

    unless tags[:async] do
      Sandbox.mode(TdCx.Repo, {:shared, self()})
    end

    cond do
      tags[:admin_authenticated] ->
        user = create_user(@admin_user_name, is_admin: true)
        create_user_auth_conn(user)

      tags[:authenticated_no_admin_user] ->
        user = create_user(tags[:authenticated_no_admin_user], is_admin: false)
        create_user_auth_conn(user, :not_admin)

      true ->
        {:ok, conn: Phoenix.ConnTest.build_conn()}
    end

  end
end
