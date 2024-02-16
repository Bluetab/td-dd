defmodule TdDdWeb.Schema.FunctionsTest do
  use TdDdWeb.ConnCase

  @functions """
  query Functions {
    functions {
      id
      name
      returnType
      group
      scope
      args {
        name
        type
        values
      }
    }
  }
  """

  describe "functions query" do
    @tag authentication: [role: "user"]
    test "returns forbidden when queried by user with no permissions", %{conn: conn} do
      assert %{"errors" => errors} =
               conn
               |> post("/api/v2", %{"query" => @functions})
               |> json_response(:ok)

      assert [%{"message" => "forbidden", "path" => ["functions"]}] = errors
    end

    @tag authentication: [role: "user", permissions: ["manage_quality_rule_implementations"]]
    test "returns data when queried by a user with permissions", %{conn: conn} do
      %{name: name} = insert(:function, args: [build(:argument, name: "foo")])

      assert %{"data" => data} =
               resp =
               conn
               |> post("/api/v2", %{"query" => @functions})
               |> json_response(:ok)

      refute Map.has_key?(resp, "errors")
      assert %{"functions" => [function]} = data
      assert %{"id" => _, "name" => ^name, "args" => [%{"name" => "foo", "type" => _}]} = function
    end

    @tag authentication: [role: "user", permissions: ["manage_raw_quality_rule_implementations"]]
    test "returns data when queried by a user with raw quality rule implementations permissions",
         %{conn: conn} do
      %{name: name} = insert(:function, args: [build(:argument, name: "foo")])

      assert %{"data" => data} =
               resp =
               conn
               |> post("/api/v2", %{"query" => @functions})
               |> json_response(:ok)

      refute Map.has_key?(resp, "errors")
      assert %{"functions" => [function]} = data
      assert %{"id" => _, "name" => ^name, "args" => [%{"name" => "foo", "type" => _}]} = function
    end

    @tag authentication: [role: "user", permissions: ["create_grant_request"]]
    test "returns data when queried by a user with create grant request permissions", %{
      conn: conn
    } do
      %{name: name} = insert(:function, args: [build(:argument, name: "foo")])

      assert %{"data" => data} =
               resp =
               conn
               |> post("/api/v2", %{"query" => @functions})
               |> json_response(:ok)

      refute Map.has_key?(resp, "errors")
      assert %{"functions" => [function]} = data
      assert %{"id" => _, "name" => ^name, "args" => [%{"name" => "foo", "type" => _}]} = function
    end
  end
end
