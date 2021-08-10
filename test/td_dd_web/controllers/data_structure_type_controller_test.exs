defmodule TdDdWeb.DataStructureTypeControllerTest do
  use TdDdWeb.ConnCase

  @create_attrs %{
    name: "some structure_type",
    template_id: 42,
    translation: "some translation"
  }
  @update_attrs %{
    name: "some updated structure_type",
    template_id: 43,
    translation: "some updated translation",
    metadata_views: [%{"name" => "updated", "fields" => []}]
  }
  @invalid_attrs %{name: nil, template_id: nil, translation: nil}

  setup %{conn: conn} do
    [
      conn: put_req_header(conn, "accept", "application/json"),
      template: CacheHelpers.insert_template()
    ]
  end

  describe "index" do
    @tag authentication: [role: "admin"]
    test "lists all data_structure_types", %{conn: conn} do
      insert(:data_structure_type, template_id: 123)

      assert %{"data" => [structure_type]} =
               conn
               |> get(Routes.data_structure_type_path(conn, :index))
               |> json_response(:ok)

      assert %{"template_id" => 123} = structure_type
      refute Map.has_key?(structure_type, "template")
    end

    @tag authentication: [role: "admin"]
    test "enriches template", %{conn: conn, template: %{id: template_id}} do
      insert(:data_structure_type, template_id: template_id)

      assert %{"data" => [structure_type]} =
               conn
               |> get(Routes.data_structure_type_path(conn, :index))
               |> json_response(:ok)

      assert %{"template" => %{"id" => ^template_id}} = structure_type
      refute Map.has_key?(structure_type, "template_id")
    end
  end

  describe "update data_structure_type" do
    setup do
      [data_structure_type: insert(:data_structure_type, @create_attrs)]
    end

    @tag authentication: [role: "admin"]
    test "renders data_structure_type when data is valid", %{
      conn: conn,
      data_structure_type: %{id: id}
    } do
      assert %{"data" => %{"id" => ^id}} =
               conn
               |> put(Routes.data_structure_type_path(conn, :update, id),
                 data_structure_type: @update_attrs
               )
               |> json_response(:ok)

      assert %{"data" => data} =
               conn
               |> get(Routes.data_structure_type_path(conn, :show, id))
               |> json_response(:ok)

      assert %{
               "id" => _id,
               "name" => "some updated structure_type",
               "template_id" => 43,
               "translation" => "some updated translation",
               "metadata_fields" => nil,
               "metadata_views" => [%{"fields" => [], "name" => "updated"}]
             } = data
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{
      conn: conn,
      data_structure_type: data_structure_type
    } do
      assert %{"errors" => %{} = errors} =
               conn
               |> put(Routes.data_structure_type_path(conn, :update, data_structure_type),
                 data_structure_type: @invalid_attrs
               )
               |> json_response(:unprocessable_entity)

      assert errors != %{}
    end
  end
end
