defmodule DataDictionaryWeb.DataFieldControllerTest do
  use DataDictionaryWeb.ConnCase
  import DataDictionaryWeb.Authentication, only: :functions

  alias DataDictionary.DataStructures.DataField

  @create_attrs %{business_concept_id: "42", description: "some description", name: "some name", nullable: true, precision: 42, type: "some type", last_change_at: "2010-04-17 14:00:00.000000Z", last_change_by: 42}
  @update_attrs %{business_concept_id: "43", description: "some updated description", name: "some updated name", nullable: false, precision: 43, type: "some updated type", last_change_at: "2010-04-17 14:00:00.000000Z", last_change_by: 42}
  @invalid_attrs %{business_concept_id: nil, description: nil, name: nil, nullable: nil, precision: nil, type: nil, last_change_at: nil, last_change_by: nil}

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
    test "renders data_field when data is valid", %{conn: conn} do
      data_structure = insert(:data_structure)
      creation_attrs = Map.put(@create_attrs, :data_structure_id, data_structure.id)
      conn = post conn, data_field_path(conn, :create), data_field: creation_attrs
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = recycle_and_put_headers(conn)

      conn = get conn, data_field_path(conn, :show, id)
      json_response_data = json_response(conn, 200)["data"]
      json_response_data = json_response_data
      |> Map.delete("last_change_by")
      |> Map.delete("last_change_at")
      |> Map.delete("last_change_at")

      assert json_response_data == %{
        "id" => id,
        "data_structure_id" => data_structure.id,
        "business_concept_id" => "42",
        "description" => "some description",
        "name" => "some name",
        "nullable" => true,
        "precision" => 42,
        "type" => "some type"}
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
    test "renders data_field when data is valid", %{conn: conn, data_field: %DataField{id: id} = data_field} do
      conn = put conn, data_field_path(conn, :update, data_field), data_field: @update_attrs
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = recycle_and_put_headers(conn)

      conn = get conn, data_field_path(conn, :show, id)
      json_response_data = json_response(conn, 200)["data"]
      json_response_data = json_response_data
      |> Map.delete("last_change_by")
      |> Map.delete("last_change_at")
      |> Map.delete("data_structure_id")

      assert json_response_data == %{
        "id" => id,
        "business_concept_id" => "43",
        "description" => "some updated description",
        "name" => "some updated name",
        "nullable" => false,
        "precision" => 43,
        "type" => "some updated type"}
    end

    @tag authenticated_user: @admin_user_name
    test "renders errors when data is invalid", %{conn: conn, data_field: data_field} do
      conn = put conn, data_field_path(conn, :update, data_field), data_field: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete data_field" do
    setup [:create_data_field]

    @tag authenticated_user: @admin_user_name
    test "deletes chosen data_field", %{conn: conn, data_field: data_field} do
      conn = delete conn, data_field_path(conn, :delete, data_field)
      assert response(conn, 204)

      conn = recycle_and_put_headers(conn)

      assert_error_sent 404, fn ->
        get conn, data_field_path(conn, :show, data_field)
      end
    end
  end

  defp create_data_field(_) do
    data_structure = insert(:data_structure)
    data_field = insert(:data_field, data_structure_id: data_structure.id)
    {:ok, data_field: data_field}
  end
end
