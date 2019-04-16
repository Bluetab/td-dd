defmodule TdDdWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common datastructures and query the data layer.

  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  alias Phoenix.ConnTest
  alias TdDdWeb.Endpoint
  import TdDdWeb.Authentication, only: :functions

  using do
    quote do
      # Import conveniences for testing with connections
      use ConnTest

      alias TdDdWeb.Router.Helpers, as: Routes
      import TdDd.Factory

      # The default endpoint for testing
      @endpoint Endpoint
    end
  end

  @admin_user_name "app-admin"

  setup tags do
    :ok = Sandbox.checkout(TdDd.Repo)

    unless tags[:async] do
      Sandbox.mode(TdDd.Repo, {:shared, self()})
      parent = self()

      case Process.whereis(TdDd.Search.IndexWorker) do
        nil -> nil
        pid -> Sandbox.allow(TdDd.Repo, parent, pid)
      end

      case Process.whereis(TdDd.Loader.LoaderWorker) do
        nil -> nil
        pid -> Sandbox.allow(TdDd.Repo, parent, pid)
      end
    end

    cond do
      tags[:admin_authenticated] ->
        user = find_or_create_user(@admin_user_name, is_admin: true)
        create_user_auth_conn(user)

      tags[:authenticated_user] ->
        user = find_or_create_user(tags[:authenticated_user], is_admin: true)
        create_user_auth_conn(user)

      tags[:authenticated_no_admin_user] ->
        user = find_or_create_user(tags[:authenticated_no_admin_user], is_admin: false)
        create_user_auth_conn(user)

      true ->
        {:ok, conn: ConnTest.build_conn()}
    end
  end
end
