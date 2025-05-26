defmodule TdDdWeb.SearchControllerTest do
  use TdDdWeb.ConnCase

  alias TdCluster.TestHelpers.TdAiMock

  @moduletag sandbox: :shared

  describe "embeddings" do
    @tag authentication: [role: "admin"]
    test "put embeddings action in indexer", %{conn: conn} do
      TdAiMock.Indices.exists_enabled?(&Mox.expect/4, {:ok, true})

      assert conn
             |> post(Routes.search_path(conn, :embeddings, %{}))
             |> response(:accepted)
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
end
