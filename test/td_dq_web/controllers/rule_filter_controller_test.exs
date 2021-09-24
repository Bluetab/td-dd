defmodule TdDqWeb.RuleFilterControllerTest do
  use TdDqWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger_dq.json"

  describe "index" do
    @tag authentication: [role: "admin"]
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
