defmodule TdDdWeb.DataStructureTypeControllerTest do
  use TdDdWeb.ConnCase

  alias TdCache.TemplateCache
  alias TdDd.DataStructures.DataStructureTypes

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

  setup_all do
    start_supervised(TdDd.Permissions.MockPermissionResolver)
    :ok
  end

  setup %{conn: conn} do
    %{id: id} = template = build(:template)
    TemplateCache.put(template, publish: false)

    on_exit(fn ->
      TemplateCache.delete(id)
    end)

    [conn: put_req_header(conn, "accept", "application/json"), template: template]
  end

  describe "index" do
    @tag :admin_authenticated
    test "lists all data_structure_types", %{conn: conn} do
      insert(:data_structure_type, template_id: 123)

      assert %{"data" => [structure_type]} =
               conn
               |> get(Routes.data_structure_type_path(conn, :index))
               |> json_response(:ok)

      assert %{"template_id" => 123} = structure_type
      refute Map.has_key?(structure_type, "template")
    end

    @tag :admin_authenticated
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

  describe "create data_structure_type" do
    @tag :admin_authenticated
    test "renders data_structure_type when data is valid", %{conn: conn} do
      assert %{"data" => %{"id" => id}} =
               conn
               |> post(Routes.data_structure_type_path(conn, :create),
                 data_structure_type: @create_attrs
               )
               |> json_response(:created)

      assert %{"data" => data} =
               conn
               |> get(Routes.data_structure_type_path(conn, :show, id))
               |> json_response(:ok)

      assert %{
               "id" => _id,
               "structure_type" => "some structure_type",
               "template_id" => 42,
               "translation" => "some translation",
               "metadata_fields" => nil
             } = data
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn} do
      assert %{"errors" => %{} = errors} =
               conn
               |> post(Routes.data_structure_type_path(conn, :create),
                 data_structure_type: @invalid_attrs
               )
               |> json_response(:unprocessable_entity)

      assert errors != %{}
    end
  end

  describe "update data_structure_type" do
    setup [:create_data_structure_type]

    @tag :admin_authenticated
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
               "structure_type" => "some updated structure_type",
               "template_id" => 43,
               "translation" => "some updated translation",
               "metadata_fields" => nil
             } = data
    end

    @tag :admin_authenticated
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

  describe "delete data_structure_type" do
    setup [:create_data_structure_type]

    @tag :admin_authenticated
    test "deletes chosen data_structure_type", %{
      conn: conn,
      data_structure_type: data_structure_type
    } do
      assert conn
             |> delete(Routes.data_structure_type_path(conn, :delete, data_structure_type))
             |> response(:no_content)

      assert_error_sent :not_found, fn ->
        get(conn, Routes.data_structure_type_path(conn, :show, data_structure_type))
      end
    end
  end

  defp create_data_structure_type(_) do
    {:ok, data_structure_type} = DataStructureTypes.create_data_structure_type(@create_attrs)
    %{data_structure_type: data_structure_type}
  end
end
