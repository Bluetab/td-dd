defmodule DataDictionaryWeb.ConnCase do
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

  alias DataDictionaryWeb.Router.Helpers
  alias Phoenix.ConnTest
  alias DataDictionaryWeb.Endpoint
  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      # Import conveniences for testing with connections
      use ConnTest
      import Helpers

      # The default endpoint for testing
      @endpoint Endpoint
    end
  end

  setup tags do
    :ok = Sandbox.checkout(DataDictionary.Repo)
    unless tags[:async] do
      Sandbox.mode(DataDictionary.Repo, {:shared, self()})
    end
    {:ok, conn: ConnTest.build_conn()}
  end

end
