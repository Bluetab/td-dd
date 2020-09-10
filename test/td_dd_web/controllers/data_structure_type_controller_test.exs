defmodule TdDdWeb.DataStructureTypeControllerTest do
  use TdDdWeb.ConnCase

  alias TdDd.DataStructures.DataStructuresTypes
  alias TdDd.DataStructures.DataStructureType
  alias TdDd.Permissions.MockPermissionResolver
  alias TdDdWeb.ApiServices.MockTdAuthService

  setup_all do
    start_supervised(MockTdAuthService)
    start_supervised(MockPermissionResolver)
    :ok
  end

  @create_attrs %{
    structure_type: "some structure_type",
    template_id: 42,
    translation: "some translation"
  }
  @update_attrs %{
    structure_type: "some updated structure_type",
    template_id: 43,
    translation: "some updated translation"
  }
  @invalid_attrs %{structure_type: nil, template_id: nil, translation: nil}

  def fixture(:data_structure_type) do
    {:ok, data_structure_type} = DataStructuresTypes.create_data_structure_type(@create_attrs)
    data_structure_type
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    @tag :admin_authenticated
    test "lists all data_structure_types", %{conn: conn} do
      conn = get(conn, Routes.data_structure_type_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create data_structure_type" do
    @tag :admin_authenticated
    test "renders data_structure_type when data is valid", %{conn: conn} do
      conn =
        post(conn, Routes.data_structure_type_path(conn, :create),
          data_structure_type: @create_attrs
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.data_structure_type_path(conn, :show, id))

      assert %{
               "id" => id,
               "structure_type" => "some structure_type",
               "template_id" => 42,
               "translation" => "some translation",
               "metadata_fields" => nil
             } = json_response(conn, 200)["data"]
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn} do
      conn =
        post(conn, Routes.data_structure_type_path(conn, :create),
          data_structure_type: @invalid_attrs
        )

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update data_structure_type" do
    setup [:create_data_structure_type]

    @tag :admin_authenticated
    test "renders data_structure_type when data is valid", %{
      conn: conn,
      data_structure_type: %DataStructureType{id: id} = data_structure_type
    } do
      conn =
        put(conn, Routes.data_structure_type_path(conn, :update, data_structure_type),
          data_structure_type: @update_attrs
        )

      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.data_structure_type_path(conn, :show, id))

      assert %{
               "id" => id,
               "structure_type" => "some updated structure_type",
               "template_id" => 43,
               "translation" => "some updated translation",
               "metadata_fields" => nil
             } = json_response(conn, 200)["data"]
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{
      conn: conn,
      data_structure_type: data_structure_type
    } do
      conn =
        put(conn, Routes.data_structure_type_path(conn, :update, data_structure_type),
          data_structure_type: @invalid_attrs
        )

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete data_structure_type" do
    setup [:create_data_structure_type]

    @tag :admin_authenticated
    test "deletes chosen data_structure_type", %{
      conn: conn,
      data_structure_type: data_structure_type
    } do
      conn = delete(conn, Routes.data_structure_type_path(conn, :delete, data_structure_type))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.data_structure_type_path(conn, :show, data_structure_type))
      end
    end
  end

  defp create_data_structure_type(_) do
    data_structure_type = fixture(:data_structure_type)
    %{data_structure_type: data_structure_type}
  end
end
