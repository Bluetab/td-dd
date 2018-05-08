defmodule TdDdWeb.DataStructureControllerTest do
  use TdDdWeb.ConnCase
  import TdDdWeb.Authentication, only: :functions
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdDd.DataStructures.DataStructure
  alias TdDdWeb.ApiServices.MockTdAuthService

  @create_attrs %{description: "some description", group: "some group", last_change_at: "2010-04-17 14:00:00.000000Z", last_change_by: 42, name: "some name", system: "some system", type: "csv", ou: "GM", lopd: "1"}
  @update_attrs %{description: "some updated description", group: "some updated group", last_change_at: "2011-05-18 15:01:01.000000Z", last_change_by: 43, name: "some updated name", system: "some updated system",  type: "table", ou: "EM", lopd: "2"}
  @invalid_attrs %{description: nil, group: nil, last_change_at: nil, last_change_by: nil, name: nil, system: nil,  type: nil, ou: nil, lopd: nil}

  setup_all do
    start_supervised MockTdAuthService
    :ok
  end

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
    test "renders data_structure when data is valid", %{conn: conn, swagger_schema: schema} do
      conn = post conn, data_structure_path(conn, :create), data_structure: @create_attrs
      assert %{"id" => id} = json_response(conn, 201)["data"]
      validate_resp_schema(conn, schema, "DataStructureResponse")

      conn = recycle_and_put_headers(conn)

      conn = get conn, data_structure_path(conn, :show, id)
      json_response_data = json_response(conn, 200)["data"]
      json_response_data = json_response_data
      |> Map.delete("last_change_by")
      |> Map.delete("last_change_at")
      validate_resp_schema(conn, schema, "DataStructureResponse")
      assert json_response_data["id"] == id
      assert json_response_data["description"] == "some description"
      assert json_response_data["type"] == "csv"
      assert json_response_data["ou"] == "GM"
      assert json_response_data["lopd"] == "1"
      assert json_response_data["group"] == "some group"
      assert json_response_data["name"] == "some name"
      assert json_response_data["system"] == "some system"
      assert json_response_data["inserted_at"]

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
    test "renders data_structure when data is valid", %{conn: conn, data_structure: %DataStructure{id: id} = data_structure, swagger_schema: schema} do
      conn = put conn, data_structure_path(conn, :update, data_structure), data_structure: @update_attrs
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = recycle_and_put_headers(conn)

      conn = get conn, data_structure_path(conn, :show, id)
      json_response_data = json_response(conn, 200)["data"]
      json_response_data = json_response_data
      |> Map.delete("last_change_by")
      |> Map.delete("last_change_at")
      validate_resp_schema(conn, schema, "DataStructureResponse")
      assert json_response_data["id"] == id
      assert json_response_data["description"] == "some updated description"
      assert json_response_data["type"] == "table"
      assert json_response_data["ou"] == "EM"
      assert json_response_data["lopd"] == "2"
      assert json_response_data["group"] == "some updated group"
      assert json_response_data["name"] == "some updated name"
      assert json_response_data["system"] == "some updated system"
      assert json_response_data["inserted_at"]

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
    test "deletes chosen data_structure", %{conn: conn, data_structure: data_structure, swagger_schema: schema} do
      conn = delete conn, data_structure_path(conn, :delete, data_structure)
      assert response(conn, 204)

      conn = recycle_and_put_headers(conn)

      assert_error_sent 404, fn ->
        get conn, data_structure_path(conn, :show, data_structure)
        validate_resp_schema(conn, schema, "DataStructureResponse")
      end
    end
  end

  defp create_data_structure(_) do
    data_structure = insert(:data_structure)
    {:ok, data_structure: data_structure}
  end
end
