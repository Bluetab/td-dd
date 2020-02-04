defmodule TdDdWeb.RelationTypeControllerTest do
  use TdDdWeb.ConnCase

  alias TdDd.DataStructures.RelationType
  alias TdDd.DataStructures.RelationTypes
  alias TdDd.Permissions.MockPermissionResolver
  alias TdDdWeb.ApiServices.MockTdAuditService
  alias TdDdWeb.ApiServices.MockTdAuthService

  @create_attrs %{
    description: "some description",
    name: "some name"
  }
  @update_attrs %{
    description: "some updated description",
    name: "some updated name"
  }
  @invalid_attrs %{description: nil, name: nil}

  @admin_user_name "app-admin"

  setup_all do
    start_supervised(MockTdAuthService)
    start_supervised(MockTdAuditService)
    start_supervised(MockPermissionResolver)
    :ok
  end

  def fixture(:relation_type) do
    {:ok, relation_type} = RelationTypes.create_relation_type(@create_attrs)
    relation_type
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    @tag authenticated_user: @admin_user_name
    test "lists all relation_types", %{conn: conn} do
      conn = get(conn, Routes.relation_type_path(conn, :index))
      assert json_response(conn, 200)["data"] == [%{"description" => "Parent/Child", "id" => 1, "name" => "default"}]
    end
  end

  describe "create relation_type" do
    @tag authenticated_user: @admin_user_name
    test "renders relation_type when data is valid", %{conn: conn} do
      conn = post(conn, Routes.relation_type_path(conn, :create), relation_type: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.relation_type_path(conn, :show, id))

      assert %{
               "id" => id,
               "description" => "some description",
               "name" => "some name"
             } = json_response(conn, 200)["data"]
    end

    @tag authenticated_user: @admin_user_name
    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.relation_type_path(conn, :create), relation_type: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update relation_type" do
    setup [:create_relation_type]

    @tag authenticated_user: @admin_user_name
    test "renders relation_type when data is valid", %{conn: conn, relation_type: %RelationType{id: id} = relation_type} do
      conn = put(conn, Routes.relation_type_path(conn, :update, relation_type), relation_type: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.relation_type_path(conn, :show, id))

      assert %{
               "id" => id,
               "description" => "some updated description",
               "name" => "some updated name"
             } = json_response(conn, 200)["data"]
    end

    @tag authenticated_user: @admin_user_name
    test "renders errors when data is invalid", %{conn: conn, relation_type: relation_type} do
      conn = put(conn, Routes.relation_type_path(conn, :update, relation_type), relation_type: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete relation_type" do
    setup [:create_relation_type]

    @tag authenticated_user: @admin_user_name
    test "deletes chosen relation_type", %{conn: conn, relation_type: relation_type} do
      conn = delete(conn, Routes.relation_type_path(conn, :delete, relation_type))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.relation_type_path(conn, :show, relation_type))
      end
    end
  end

  defp create_relation_type(_) do
    relation_type = fixture(:relation_type)
    {:ok, relation_type: relation_type}
  end
end
