defmodule TdDqWeb.ImplementationFilterControllerTest do
  use TdDqWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger_dq.json"

  describe "index" do
    @tag authentication: [role: "admin"]
    test "search filters should return at least the informed filters", %{conn: conn} do
      filters = %{"current_business_concept_version" => ["bc"]}

      assert %{"data" => data} =
               conn
               |> post(Routes.implementation_filter_path(conn, :search, %{"filters" => filters}))
               |> json_response(:ok)

      assert data == %{"current_business_concept_version.name.raw" => ["bc"]}
    end
  end
end
