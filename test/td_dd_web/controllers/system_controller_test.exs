defmodule TdDdWeb.SystemControllerTest do
  use TdDdWeb.ConnCase

  alias TdDd.DataStructures
  alias TdDd.DataStructures.System
  alias TdDd.Permissions.MockPermissionResolver
  alias TdDdWeb.ApiServices.MockTdAuthService

  @create_attrs %{
    external_ref: "some external_ref",
    name: "some name"
  }
  @update_attrs %{
    external_ref: "some updated external_ref",
    name: "some updated name"
  }
  @invalid_attrs %{external_ref: nil, name: nil}

  setup_all do
    start_supervised(MockPermissionResolver)
    start_supervised(MockTdAuthService)
    :ok
  end

  def fixture(:system) do
    {:ok, system} = DataStructures.create_system(@create_attrs)
    system
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  @admin_user_name "app-admin"

  describe "index" do
    @tag authenticated_user: @admin_user_name
    test "lists all systems", %{conn: conn} do
      conn = get(conn, Routes.system_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create system" do
    @tag authenticated_user: @admin_user_name
    test "renders system when data is valid", %{conn: conn} do
      conn = post(conn, Routes.system_path(conn, :create), system: @create_attrs)
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.system_path(conn, :show, id))

      assert %{
               "id" => id,
               "external_ref" => "some external_ref",
               "name" => "some name"
             } == json_response(conn, 200)["data"]
    end

    @tag authenticated_user: @admin_user_name
    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.system_path(conn, :create), system: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update system" do
    setup [:create_system]

    @tag authenticated_user: @admin_user_name
    test "renders system when data is valid", %{conn: conn, system: %System{id: id} = system} do
      conn = put(conn, Routes.system_path(conn, :update, system), system: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.system_path(conn, :show, id))

      assert %{
               "id" => id,
               "external_ref" => "some updated external_ref",
               "name" => "some updated name"
             } == json_response(conn, 200)["data"]
    end

    @tag authenticated_user: @admin_user_name
    test "renders errors when data is invalid", %{conn: conn, system: system} do
      conn = put(conn, Routes.system_path(conn, :update, system), system: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete system" do
    setup [:create_system]

    @tag authenticated_user: @admin_user_name
    test "deletes chosen system", %{conn: conn, system: system} do
      conn = delete(conn, Routes.system_path(conn, :delete, system))
      assert response(conn, 204)

      assert_error_sent(404, fn ->
        get(conn, Routes.system_path(conn, :show, system))
      end)
    end
  end

  defp create_system(_) do
    system = fixture(:system)
    {:ok, system: system}
  end
end
