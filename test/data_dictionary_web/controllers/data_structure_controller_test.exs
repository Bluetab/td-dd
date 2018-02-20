defmodule DataDictionaryWeb.DataStructureControllerTest do
  use DataDictionaryWeb.ConnCase
  import DataDictionaryWeb.Authentication, only: :functions

  alias DataDictionary.DataStructures.DataStructure

  @create_attrs %{description: "some description", group: "some group", last_change: "2010-04-17 14:00:00.000000Z", modifier: 42, name: "some name", system: "some system"}
  @update_attrs %{description: "some updated description", group: "some updated group", last_change: "2011-05-18 15:01:01.000000Z", modifier: 43, name: "some updated name", system: "some updated system"}
  @invalid_attrs %{description: nil, group: nil, last_change: nil, modifier: nil, name: nil, system: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  @admin_user_name "app-admin"

  describe "index" do

    @tag authenticated_user: @admin_user_name
    test "lists all data_structures", %{conn: conn} do
      conn = get conn, data_structure_path(conn, :index)
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create data_structure" do
    @tag authenticated_user: @admin_user_name
    test "renders data_structure when data is valid", %{conn: conn} do
      conn = post conn, data_structure_path(conn, :create), data_structure: @create_attrs
      assert %{"id" => id} = json_response(conn, 201)["data"]

     conn = recycle_and_put_headers(conn)

      conn = get conn, data_structure_path(conn, :show, id)
      json_response_data = json_response(conn, 200)["data"]
      json_response_data = json_response_data
      |> Map.delete("modifier")
      |> Map.delete("last_change")
      assert  json_response_data == %{
        "id" => id,
        "description" => "some description",
        "group" => "some group",
        "name" => "some name",
        "system" => "some system"}
    end

    @tag authenticated_user: @admin_user_name
    test "renders errors when data is invalid", %{conn: conn} do
      conn = post conn, data_structure_path(conn, :create), data_structure: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update data_structure" do
    setup [:create_data_structure]

    @tag authenticated_user: @admin_user_name
    test "renders data_structure when data is valid", %{conn: conn, data_structure: %DataStructure{id: id} = data_structure} do
      conn = put conn, data_structure_path(conn, :update, data_structure), data_structure: @update_attrs
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = recycle_and_put_headers(conn)

      conn = get conn, data_structure_path(conn, :show, id)
      json_response_data = json_response(conn, 200)["data"]
      json_response_data = json_response_data
      |> Map.delete("modifier")
      |> Map.delete("last_change")

      assert json_response_data == %{
        "id" => id,
        "description" => "some updated description",
        "group" => "some updated group",
        "name" => "some updated name",
        "system" => "some updated system"}
    end

    @tag authenticated_user: @admin_user_name
    test "renders errors when data is invalid", %{conn: conn, data_structure: data_structure} do
      conn = put conn, data_structure_path(conn, :update, data_structure), data_structure: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete data_structure" do
    setup [:create_data_structure]

    @tag authenticated_user: @admin_user_name
    test "deletes chosen data_structure", %{conn: conn, data_structure: data_structure} do
      conn = delete conn, data_structure_path(conn, :delete, data_structure)
      assert response(conn, 204)

      conn = recycle_and_put_headers(conn)

      assert_error_sent 404, fn ->
        get conn, data_structure_path(conn, :show, data_structure)
      end
    end
  end

  defp create_data_structure(_) do
    data_structure = insert(:data_structure)
    {:ok, data_structure: data_structure}
  end
end
