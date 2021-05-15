defmodule TdDdWeb.ConnCase do
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

  import TdDdWeb.Authentication, only: :functions

  alias Ecto.Adapters.SQL.Sandbox
  alias Phoenix.ConnTest
  alias TdDdWeb.Endpoint

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import TdDd.Factory

      import TdDdWeb.Authentication, only: [create_acl_entry: 3]

      alias TdCxWeb.Router.Helpers, as: CxRoutes
      alias TdDdWeb.Router.Helpers, as: Routes
      alias TdDqWeb.Router.Helpers, as: DqRoutes

      # The default endpoint for testing
      @endpoint Endpoint
    end
  end

  setup tags do
    start_supervised(MockPermissionResolver)

    case Sandbox.checkout(TdDd.Repo) do
      :ok ->
        if tags[:async] or tags[:sandbox] == :shared do
          Sandbox.mode(TdDd.Repo, {:shared, self()})
        else
          parent = self()

          allow(parent, [
            TdDd.Cache.SystemLoader,
            TdDd.Loader.Worker,
            TdDd.Search.IndexWorker,
            TdDd.Cache.StructureLoader,
            TdDd.Lineage,
            TdDd.Lineage.GraphData
          ])
        end

      {:already, :owner} ->
        :ok
    end

    case tags[:authentication] do
      nil ->
        [conn: ConnTest.build_conn()]

      auth_opts ->
        auth_opts
        |> create_claims()
        |> create_user_auth_conn()
    end
  end

  defp allow(parent, workers) do
    Enum.each(workers, fn worker ->
      case Process.whereis(worker) do
        nil -> nil
        pid -> Sandbox.allow(TdDd.Repo, parent, pid)
      end
    end)
  end
end
