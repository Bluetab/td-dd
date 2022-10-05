defmodule TdDqWeb.FunctionControllerTest do
  use TdDqWeb.ConnCase

  describe "POST /api/functions" do
    @tag authentication: [role: "user", permissions: ["manage_quality_rule_implementations"]]
    test "response forbidden for a user without permissions", %{conn: conn} do
      params = string_params_for(:function)

      assert %{"errors" => _errors} =
               conn
               |> post(Routes.function_path(conn, :create), params)
               |> json_response(:forbidden)
    end

    @tag authentication: [role: "admin"]
    test "creates a function", %{conn: conn} do
      %{"name" => name} = params = string_params_for(:function)

      assert %{"data" => data} =
               conn
               |> post(Routes.function_path(conn, :create), params)
               |> json_response(:ok)

      assert %{
               "args" => [%{"type" => _}],
               "id" => _,
               "name" => ^name,
               "return_type" => _
             } = data
    end
  end

  describe "DELETE /api/functions/:id" do
    @tag authentication: [role: "user", permissions: ["manage_quality_rule_implementations"]]
    test "response forbidden for a user without permissions", %{conn: conn} do
      %{id: id} = insert(:function)

      assert %{"errors" => _errors} =
               conn
               |> delete(Routes.function_path(conn, :delete, id))
               |> json_response(:forbidden)
    end

    @tag authentication: [role: "admin"]
    test "deletes a function", %{conn: conn} do
      %{id: id} = insert(:function)

      assert conn
             |> delete(Routes.function_path(conn, :delete, id))
             |> response(:no_content)
    end
  end
end
