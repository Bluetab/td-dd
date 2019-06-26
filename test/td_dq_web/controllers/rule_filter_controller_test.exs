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
    @tag authenticated_user: "app-admin"
    test "search filters should return at least the informed filters", %{conn: conn} do
      filters = %{"rule_type" => ["TYPE1", "TYPE2"], "active.raw" => [true]}

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
               "rule_type.name.raw" => ["TYPE1", "TYPE2"],
               "active.raw" => ["true"]
             }
    end
  end
end
