defmodule TdDqWeb.RuleFilterControllerTest do
  use TdDqWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdDqWeb.ApiServices.MockTdAuditService

  setup_all do
    start_supervised(MockTdAuditService)
    :ok
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    @tag :admin_authenticated
    test "search filters should return at least the informed filters", %{conn: conn} do
      filters = %{"active.raw" => [true]}

      conn =
        post(
          conn,
          Routes.rule_filter_path(
            conn,
            :search,
            %{"filters" => filters}
          )
        )

      assert json_response(conn, 200)["data"] == %{
               "active.raw" => ["true"]
             }
    end
  end
end
