defmodule TdDdWeb.GrantApproverControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  @moduletag sandbox: :shared

  describe "index" do
    @tag authentication: [role: "admin"]
    test "list grants when user has permissions", %{conn: conn, swagger_schema: schema} do
      %{id: id, name: name} = insert(:grant_approver)

      assert %{"data" => [%{"id" => ^id, "name" => ^name}]} =
               conn
               |> get(Routes.grant_approver_path(conn, :index))
               |> validate_resp_schema(schema, "GrantApproversResponse")
               |> json_response(:ok)
    end

    @tag authentication: [role: "user"]
    test "forbidden when users has no permissions", %{conn: conn} do
      insert(:grant_approver)

      assert %{"errors" => %{"detail" => "Invalid authorization"}} =
               conn
               |> get(Routes.grant_approver_path(conn, :index))
               |> json_response(:forbidden)
    end
  end

  describe "create grant approver" do
    @tag authentication: [role: "admin"]
    test "creates gran approver when attributes are valid", %{conn: conn, swagger_schema: schema} do
      %{"name" => name} = params = string_params_for(:grant_approver)

      assert %{"data" => %{"name" => ^name}} =
               conn
               |> post(Routes.grant_approver_path(conn, :create, params),
                 grant_approver: params
               )
               |> validate_resp_schema(schema, "GrantApproverResponse")
               |> json_response(:created)
    end

    @tag authentication: [role: "admin"]
    test "renders error if name no specified", %{conn: conn} do
      assert %{"errors" => %{"name" => ["required"]}} =
               conn
               |> post(Routes.grant_approver_path(conn, :create),
                 grant_approver: %{}
               )
               |> json_response(:unprocessable_entity)
    end

    @tag authentication: [role: "admin"]
    test "renders error if name duplicated", %{conn: conn} do
      %{name: name} = insert(:grant_approver)

      assert %{"errors" => %{"name" => ["unique"]}} =
               conn
               |> post(Routes.grant_approver_path(conn, :create),
                 grant_approver: %{name: name}
               )
               |> json_response(:unprocessable_entity)
    end

    @tag authentication: [role: "user"]
    test "renders forbidden if no admin", %{conn: conn} do
      params = string_params_for(:grant_approver)

      assert %{"errors" => %{"detail" => "Invalid authorization"}} =
               conn
               |> post(Routes.grant_approver_path(conn, :create),
                 grant_approver: params
               )
               |> json_response(:forbidden)
    end
  end

  describe "show" do
    @tag authentication: [role: "admin"]
    test "gets grant approver when user has permissions", %{conn: conn, swagger_schema: schema} do
      %{id: id, name: name} = insert(:grant_approver)

      assert %{"data" => %{"id" => ^id, "name" => ^name}} =
               conn
               |> get(Routes.grant_approver_path(conn, :show, id))
               |> validate_resp_schema(schema, "GrantApproverResponse")
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "not found when it does not exist", %{conn: conn} do
      id = System.unique_integer([:positive])

      assert_error_sent(:not_found, fn ->
        get(conn, Routes.grant_approver_path(conn, :show, id))
      end)
    end

    @tag authentication: [role: "user"]
    test "forbidden if role is not admin", %{conn: conn} do
      %{id: id} = insert(:grant_approver)

      assert %{"errors" => %{"detail" => "Invalid authorization"}} =
               conn
               |> get(Routes.grant_approver_path(conn, :show, id))
               |> json_response(:forbidden)
    end
  end

  describe "delete grant approval" do
    @tag authentication: [role: "admin"]
    test "deletes grant approval", %{
      conn: conn
    } do
      %{id: id} = insert(:grant_approver)

      assert conn
             |> delete(Routes.grant_approver_path(conn, :delete, id))
             |> response(:no_content)

      assert_error_sent(:not_found, fn ->
        get(conn, Routes.grant_approver_path(conn, :show, id))
      end)
    end

    @tag authentication: [role: "admin"]
    test "grant approval not found", %{
      conn: conn
    } do
      id = System.unique_integer([:positive])

      assert_error_sent(:not_found, fn ->
        delete(conn, Routes.grant_approver_path(conn, :delete, id))
      end)
    end

    @tag authentication: [role: "user"]
    test "forbidden", %{
      conn: conn
    } do
      %{id: id} = insert(:grant_approver)

      assert %{"errors" => %{"detail" => "Invalid authorization"}} =
               conn
               |> delete(Routes.grant_approver_path(conn, :delete, id))
               |> json_response(:forbidden)
    end
  end
end
