defmodule TdDdWeb.DataStructureFilterControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  import Mox

  @aggregations %{
    "foo" => %{
      "buckets" => [%{"key" => "bar"}, %{"key" => "baz"}]
    }
  }

  setup_all do
    start_supervised!(TdDd.Search.Cluster)
    :ok
  end

  setup :verify_on_exit!

  describe "index" do
    @tag authentication: [role: "admin"]
    test "lists all filters (admin user)", %{conn: conn} do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", %{query: query}, [] ->
        assert query == %{bool: %{filter: %{match_all: %{}}}}
        SearchHelpers.aggs_response(@aggregations)
      end)

      assert %{"data" => data} =
               conn
               |> get(Routes.data_structure_filter_path(conn, :index))
               |> json_response(:ok)

      assert data == %{"foo" => ["bar", "baz"]}
    end

    @tag authentication: [user_name: "non_admin_user"]
    test "lists all filters (non-admin user)", %{conn: conn} do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", %{query: query}, [] ->
        assert query == %{bool: %{filter: %{match_none: %{}}}}
        SearchHelpers.aggs_response(%{})
      end)

      assert %{"data" => data} =
               conn
               |> get(Routes.data_structure_filter_path(conn, :index))
               |> json_response(:ok)

      assert data == %{}
    end
  end
end
