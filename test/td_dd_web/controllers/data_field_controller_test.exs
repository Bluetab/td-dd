defmodule TdDdWeb.DataFieldControllerTest do
  use TdDdWeb.ConnCase
  import TdDdWeb.Authentication, only: :functions
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdDd.DataStructures.DataField
  alias TdDdWeb.ApiServices.MockTdAuthService
  alias TdDdWeb.ApiServices.MockTdAuditService

  @create_attrs %{business_concept_id: "42", description: "some description", name: "some name", nullable: true, precision: "some precision", type: "some type", last_change_at: "2010-04-17 14:00:00.000000Z", last_change_by: 42}
  @update_attrs %{business_concept_id: "43", description: "some updated description", name: "some updated name", nullable: false, precision: "some precision", type: "some updated type", last_change_at: "2010-04-17 14:00:00.000000Z", last_change_by: 42}
  @invalid_attrs %{business_concept_id: nil, description: nil, name: nil, nullable: nil, precision: "some precision", type: nil, last_change_at: nil, last_change_by: nil}

  setup_all do
    start_supervised MockTdAuthService
    start_supervised MockTdAuditService
    :ok
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  @admin_user_name "app-admin"

  describe "index" do
    @tag authenticated_user: @admin_user_name
    test "lists all data_fields", %{conn: conn} do
      conn = get conn, data_field_path(conn, :index)
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create data_field" do
    @tag authenticated_user: @admin_user_name
    test "renders data_field when data is valid", %{conn: conn, swagger_schema: schema} do
      data_structure = insert(:data_structure)
      creation_attrs = Map.put(@create_attrs, :data_structure_id, data_structure.id)
      conn = post conn, data_field_path(conn, :create), data_field: creation_attrs
      assert %{"id" => id} = json_response(conn, 201)["data"]
      validate_resp_schema(conn, schema, "DataFieldResponse")

      conn = recycle_and_put_headers(conn)

      conn = get conn, data_field_path(conn, :show, id)
      json_response_data = json_response(conn, 200)["data"]
      json_response_data = json_response_data
      |> Map.delete("last_change_by")
      |> Map.delete("last_change_at")
      |> Map.delete("last_change_at")

      validate_resp_schema(conn, schema, "DataFieldResponse")
      assert json_response_data["id"] == id
      assert json_response_data["data_structure_id"] == data_structure.id
      assert json_response_data["business_concept_id"] == "42"
      assert json_response_data["description"] == "some description"
      assert json_response_data["name"] == "some name"
      assert json_response_data["nullable"] ==  true
      assert json_response_data["precision"] == "some precision"
      assert json_response_data["type"] == "some type"

    end

    @tag authenticated_user: @admin_user_name
    test "renders errors when data is invalid", %{conn: conn} do
      conn = post conn, data_field_path(conn, :create), data_field: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update data_field" do
    setup [:create_data_field]

    @tag authenticated_user: @admin_user_name
    test "renders data_field when data is valid", %{conn: conn, data_field: %DataField{id: id} = data_field, swagger_schema: schema} do
      conn = put conn, data_field_path(conn, :update, data_field), data_field: @update_attrs
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = recycle_and_put_headers(conn)

      conn = get conn, data_field_path(conn, :show, id)
      json_response_data = json_response(conn, 200)["data"]
      json_response_data = json_response_data
      |> Map.delete("last_change_by")
      |> Map.delete("last_change_at")
      |> Map.delete("data_structure_id")

      validate_resp_schema(conn, schema, "DataFieldResponse")
      assert json_response_data["id"] == id
      assert json_response_data["description"] == "some updated description"
    end

  end

  describe "delete data_field" do
    setup [:create_data_field]

    @tag authenticated_user: @admin_user_name
    test "deletes chosen data_field", %{conn: conn, data_field: data_field, swagger_schema: schema} do
      conn = delete conn, data_field_path(conn, :delete, data_field)
      assert response(conn, 204)

      conn = recycle_and_put_headers(conn)

      assert_error_sent 404, fn ->
        get conn, data_field_path(conn, :show, data_field)
        validate_resp_schema(conn, schema, "DataFieldResponse")
      end
    end
  end

  describe "data structure fields" do
    setup [:create_data_field]

    @tag authenticated_user: @admin_user_name
    test "lists data structure fields ", %{conn: conn, data_field: data_field, swagger_schema: schema} do
      conn = get conn, data_structure_data_field_path(conn, :data_structure_fields, data_field.data_structure_id)
      validate_resp_schema(conn, schema, "DataFieldsResponse")
      data_fields = json_response(conn, 200)["data"]
      assert length(data_fields) == 1
      assert data_fields |> Enum.at(0) |> Map.get("id") == data_field.id
    end
  end

  defp create_data_field(_) do
    data_structure = insert(:data_structure)
    data_field = insert(:data_field, data_structure_id: data_structure.id)
    {:ok, data_field: data_field}
  end
end
