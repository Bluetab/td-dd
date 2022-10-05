defmodule TdDqWeb.FunctionsControllerTest do
  use TdDqWeb.ConnCase

  describe "show" do
    @tag authentication: [role: "user"]
    test "response forbidden for a user without permissions", %{conn: conn} do
      assert %{"errors" => _errors} =
               conn
               |> get(Routes.functions_path(conn, :show))
               |> json_response(:forbidden)
    end

    @tag authentication: [role: "user", permissions: ["manage_quality_rule_implementations"]]
    test "returns functions", %{conn: conn} do
      %{id: id, name: name, return_type: return_type} = insert(:function)

      assert %{"data" => data} =
               conn
               |> get(Routes.functions_path(conn, :show))
               |> json_response(:ok)

      assert [
               %{
                 "args" => [%{"type" => _}],
                 "id" => ^id,
                 "name" => ^name,
                 "return_type" => ^return_type
               }
             ] = data
    end
  end
end
