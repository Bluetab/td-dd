defmodule TdDqWeb.FunctionsControllerTest do
  use TdDqWeb.ConnCase

  describe "PUT /api/functions" do
    @tag authentication: [role: "user", permissions: ["manage_quality_rule_implementations"]]
    test "response forbidden for a user without permissions", %{conn: conn} do
      assert %{"errors" => _errors} =
               conn
               |> put(Routes.functions_path(conn, :update), %{})
               |> json_response(:forbidden)
    end

    @tag authentication: [role: "admin"]
    test "returns functions", %{conn: conn} do
      params = %{"functions" => [string_params_for(:function)]}

      assert %{"data" => data} =
               conn
               |> put(Routes.functions_path(conn, :update), params)
               |> json_response(:ok)

      assert [%{"id" => _}] = data
    end
  end
end
