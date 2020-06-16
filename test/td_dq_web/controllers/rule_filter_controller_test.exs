defmodule TdDqWeb.RuleFilterControllerTest do
  use TdDqWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    @tag :admin_authenticated
    test "search filters should return at least the informed filters", %{conn: conn} do
      filters = %{"active.raw" => [true]}

      assert %{"data" => data} =
               conn
               |> post(Routes.rule_filter_path(conn, :search, %{"filters" => filters}))
               |> json_response(:ok)

      assert data == %{"active.raw" => ["true"]}
    end
  end
end
