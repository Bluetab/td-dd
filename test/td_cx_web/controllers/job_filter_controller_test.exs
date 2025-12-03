defmodule TdCxWeb.JobFilterControllerTest do
  use TdCxWeb.ConnCase

  import Mox

  setup :verify_on_exit!

  describe "search/2" do
    @tag authentication: [role: "admin"]
    test "returns job filter values", %{conn: conn} do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/jobs/_search", %{aggs: _, size: 0}, _ ->
        SearchHelpers.aggs_response(%{
          "status" => %{"buckets" => [%{"key" => "PENDING"}, %{"key" => "COMPLETED"}]},
          "type" => %{"buckets" => [%{"key" => "profile"}]}
        })
      end)

      conn = post(conn, Routes.job_filter_path(conn, :search), %{})
      assert %{"data" => filters} = json_response(conn, 200)
      assert is_map(filters)
    end

    @tag authentication: [role: "service"]
    test "returns filters for service accounts", %{conn: conn} do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/jobs/_search", %{aggs: _, size: 0}, _ ->
        SearchHelpers.aggs_response()
      end)

      conn = post(conn, Routes.job_filter_path(conn, :search), %{})
      assert %{"data" => _filters} = json_response(conn, 200)
    end

    @tag authentication: [role: "user"]
    test "returns empty filters for regular users", %{conn: conn} do
      conn = post(conn, Routes.job_filter_path(conn, :search), %{})
      assert %{"data" => filters} = json_response(conn, 200)
      assert filters == %{}
    end

    @tag authentication: [role: "admin"]
    test "accepts filter parameters", %{conn: conn} do
      params = %{"filters" => %{"status" => ["PENDING"]}}

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/jobs/_search", request, _ ->
        assert %{aggs: _, query: query, size: 0} = request
        assert %{bool: %{must: _}} = query
        SearchHelpers.aggs_response()
      end)

      conn = post(conn, Routes.job_filter_path(conn, :search), params)
      assert %{"data" => _filters} = json_response(conn, 200)
    end
  end
end
