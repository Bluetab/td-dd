defmodule TdDqWeb.ConnCase do
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

  import TdDqWeb.Authentication, only: :functions

  alias Ecto.Adapters.SQL.Sandbox
  alias Phoenix.ConnTest
  alias TdDqWeb.Endpoint

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import TdDq.Factory

      alias TdDqWeb.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint Endpoint
    end
  end

  @admin_user_name "app-admin"

  setup tags do
    :ok = Sandbox.checkout(TdDq.Repo)

    unless tags[:async] do
      Sandbox.mode(TdDq.Repo, {:shared, self()})
      parent = self()

      Enum.each([TdDq.Search.IndexWorker, TdDq.Cache.RuleLoader], fn worker ->
        case Process.whereis(worker) do
          nil ->
            nil

          pid ->
            on_exit(fn -> worker.ping(20_000) end)
            Sandbox.allow(TdDq.Repo, parent, pid)
        end
      end)
    end

    cond do
      tags[:admin_authenticated] ->
        @admin_user_name
        |> create_claims(role: "admin")
        |> create_user_auth_conn()

      user_name = tags[:authenticated_user] ->
        user_name
        |> create_claims()
        |> create_user_auth_conn(tags[:role])

      true ->
        {:ok, conn: ConnTest.build_conn()}
    end
  end
end
