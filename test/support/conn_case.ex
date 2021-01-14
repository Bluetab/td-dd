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
  alias TdDdWeb.Endpoint

  import TdDdWeb.Authentication, only: :functions

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import TdDd.Factory

      alias TdDdWeb.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint Endpoint
    end
  end

  setup tags do
    :ok = Sandbox.checkout(TdDd.Repo)

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

    cond do
      tags[:admin_authenticated] ->
        "app-admin"
        |> create_claims(role: "admin")
        |> create_user_auth_conn()

      tags[:authenticated_user] ->
        tags[:authenticated_user]
        |> create_claims()
        |> create_user_auth_conn()

      true ->
        {:ok, conn: Phoenix.ConnTest.build_conn()}
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
