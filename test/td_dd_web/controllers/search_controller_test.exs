defmodule TdDdWeb.SearchControllerTest do
  use TdDdWeb.ConnCase

  alias TdCluster.TestHelpers.TdAiMock
  alias TdCore.Search.IndexWorkerMock

  @moduletag sandbox: :shared

  describe "embeddings" do
    setup do
      IndexWorkerMock.clear()
      on_exit(fn -> IndexWorkerMock.clear() end)
      :ok
    end

    @tag authentication: [role: "admin"]
    test "put embeddings action in indexer", %{conn: conn} do
      TdAiMock.Indices.exists_enabled?(&Mox.expect/4, {:ok, true})

      assert conn
             |> post(Routes.search_path(conn, :embeddings, %{}))
             |> response(:accepted)

      assert [{:put_embeddings, :structures, :all}] == IndexWorkerMock.calls()
    end

    @tag authentication: [role: "admin"]
    test "forbidden when there are not indices enbabled", %{conn: conn} do
      TdAiMock.Indices.exists_enabled?(&Mox.expect/4, {:ok, false})

      assert %{"errors" => %{"detail" => "Invalid authorization"}} ==
               conn
               |> post(Routes.search_path(conn, :embeddings, %{}))
               |> json_response(:forbidden)
    end
  end

  describe "reindex_all" do
    setup do
      IndexWorkerMock.clear()
      on_exit(fn -> IndexWorkerMock.clear() end)
      :ok
    end

    @tag authentication: [role: "admin"]
    test "reindexes all data structures", %{conn: conn} do
      assert conn
             |> get(Routes.search_path(conn, :reindex_all))
             |> response(:accepted)

      assert [{:reindex, :structures, :all}] == IndexWorkerMock.calls()
    end

    @tag authentication: [role: "user"]
    test "user without admin role cannot reindex", %{conn: conn} do
      assert %{"errors" => %{"detail" => "Invalid authorization"}} ==
               conn
               |> get(Routes.search_path(conn, :reindex_all))
               |> json_response(:forbidden)
    end
  end
end
