defmodule TdDdWeb.Schema.RulesTest do
  use TdDdWeb.ConnCase

  @query """
  query Rules {
    rules {
      id
      name
    }
  }
  """

  describe "rules query" do
    @tag authentication: [role: "user"]
    test "returns forbidden when queried by user role", %{conn: conn} do
      assert %{"data" => data, "errors" => errors} =
               conn
               |> post("/api/v2", %{"query" => @query})
               |> json_response(:ok)

      assert data == %{"rules" => nil}
      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "admin"]
    test "returns data when queried by admin role", %{conn: conn} do
      %{id: expected_id, name: name} = insert(:rule)

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{"query" => @query})
               |> json_response(:ok)

      assert response["errors"] == nil
      assert %{"rules" => rules} = data
      assert [%{"id" => id, "name" => ^name}] = rules
      assert id == to_string(expected_id)
    end
  end
end
