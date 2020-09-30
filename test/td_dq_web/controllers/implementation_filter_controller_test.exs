defmodule TdDqWeb.ImplementationFilterControllerTest do
  use TdDqWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    @tag :admin_authenticated
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
