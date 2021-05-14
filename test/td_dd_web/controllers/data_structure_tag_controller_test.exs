defmodule TdDdWeb.DataStructureTagControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructureTag

  @create_attrs %{
    name: "some name"
  }
  @update_attrs %{
    name: "some updated name"
  }
  @invalid_attrs %{name: nil}

  def fixture(:data_structure_tag) do
    {:ok, data_structure_tag} = DataStructures.create_data_structure_tag(@create_attrs)
    data_structure_tag
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    @tag authentication: [role: "admin"]
    test "lists all data_structure_tags", %{conn: conn, swagger_schema: schema} do
      %{id: id, name: name} = insert(:data_structure_tag)

      assert %{"data" => [structure_tag]} =
               conn
               |> get(Routes.data_structure_tag_path(conn, :index))
               |> validate_resp_schema(schema, "DataStructureTagsResponse")
               |> json_response(:ok)

      assert %{"id" => ^id, "name" => ^name, "structure_count" => 0} = structure_tag
    end

    @tag authentication: [role: "admin"]
    test "lists all data_structure_tags with the count of its structures", %{
      conn: conn,
      swagger_schema: schema
    } do
      structure = insert(:data_structure)
      %{id: id, name: name} = structure_tag = insert(:data_structure_tag)
      insert(:data_structures_tags, data_structure: structure, data_structure_tag: structure_tag)

      assert %{"data" => [structure_tag]} =
               conn
               |> get(Routes.data_structure_tag_path(conn, :index))
               |> validate_resp_schema(schema, "DataStructureTagsResponse")
               |> json_response(:ok)

      assert %{"id" => ^id, "name" => ^name, "structure_count" => 1} = structure_tag
    end

    @tag authentication: [user_name: "non_admin_user"]
    test "non admin user cannot list data_structure_tags", %{conn: conn} do
      assert conn
             |> get(Routes.data_structure_tag_path(conn, :index))
             |> json_response(:forbidden)
    end
  end

  describe "show" do
    @tag authentication: [role: "admin"]
    test "show data_structure_tag", %{conn: conn, swagger_schema: schema} do
      %{id: id, name: name} = insert(:data_structure_tag)

      assert %{"data" => structure_tag} =
               conn
               |> get(Routes.data_structure_tag_path(conn, :show, id))
               |> validate_resp_schema(schema, "DataStructureTagResponse")
               |> json_response(:ok)

      assert %{"id" => ^id, "name" => ^name} = structure_tag
    end

    @tag authentication: [user_name: "non_admin_user"]
    test "non admin user cannot show data_structure_tag", %{conn: conn} do
      %{id: id} = insert(:data_structure_tag)

      assert conn
             |> get(Routes.data_structure_tag_path(conn, :show, id))
             |> json_response(:forbidden)
    end
  end

  describe "create data_structure_tag" do
    @tag authentication: [role: "admin"]
    test "renders data_structure_tag when data is valid", %{conn: conn, swagger_schema: schema} do
      assert %{"data" => %{"id" => id}} =
               conn
               |> post(Routes.data_structure_tag_path(conn, :create),
                 data_structure_tag: @create_attrs
               )
               |> validate_resp_schema(schema, "DataStructureTagResponse")
               |> json_response(:created)

      assert %{"data" => data} =
               conn
               |> get(Routes.data_structure_tag_path(conn, :show, id))
               |> json_response(:ok)

      assert %{
               "id" => ^id,
               "name" => "some name"
             } = data
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{conn: conn} do
      assert %{"errors" => %{} = errors} =
               conn
               |> post(Routes.data_structure_tag_path(conn, :create),
                 data_structure_tag: @invalid_attrs
               )
               |> json_response(:unprocessable_entity)

      assert errors != %{}
    end

    @tag authentication: [user_name: "non_admin_user"]
    test "non admin user cannot create data_structure_tags", %{conn: conn} do
      assert conn
             |> post(Routes.data_structure_tag_path(conn, :create),
               data_structure_tag: @create_attrs
             )
             |> json_response(:forbidden)
    end
  end

  describe "update data_structure_tag" do
    setup [:create_data_structure_tag]

    @tag authentication: [role: "admin"]
    test "renders data_structure_tag when data is valid", %{
      conn: conn,
      swagger_schema: schema,
      data_structure_tag: %DataStructureTag{id: id}
    } do
      assert %{"data" => %{"id" => ^id}} =
               conn
               |> put(Routes.data_structure_tag_path(conn, :update, id),
                 data_structure_tag: @update_attrs
               )
               |> validate_resp_schema(schema, "DataStructureTagResponse")
               |> json_response(:ok)

      assert %{"data" => data} =
               conn
               |> get(Routes.data_structure_tag_path(conn, :show, id))
               |> json_response(:ok)

      assert %{
               "id" => ^id,
               "name" => "some updated name"
             } = data
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{
      conn: conn,
      data_structure_tag: data_structure_tag
    } do
      assert %{"errors" => %{} = errors} =
               conn
               |> put(Routes.data_structure_tag_path(conn, :update, data_structure_tag),
                 data_structure_tag: @invalid_attrs
               )
               |> json_response(:unprocessable_entity)

      assert errors != %{}
    end

    @tag authentication: [user_name: "non_admin_user"]
    test "non admin user cannot update data_structure_tags", %{
      conn: conn,
      data_structure_tag: data_structure_tag
    } do
      assert conn
             |> put(Routes.data_structure_tag_path(conn, :update, data_structure_tag),
               data_structure_tag: @invalid_attrs
             )
             |> json_response(:forbidden)
    end
  end

  describe "delete data_structure_tag" do
    setup [:create_data_structure_tag]

    @tag authentication: [role: "admin"]
    test "deletes chosen data_structure_tag", %{
      conn: conn,
      data_structure_tag: data_structure_tag
    } do
      assert conn
             |> delete(Routes.data_structure_tag_path(conn, :delete, data_structure_tag))
             |> response(:no_content)

      assert_error_sent :not_found, fn ->
        get(conn, Routes.data_structure_tag_path(conn, :show, data_structure_tag))
      end
    end

    @tag authentication: [user_name: "non_admin_user"]
    test "non admin user cannot delete data_structure_tags", %{
      conn: conn,
      data_structure_tag: data_structure_tag
    } do
      assert conn
             |> delete(Routes.data_structure_tag_path(conn, :delete, data_structure_tag))
             |> json_response(:forbidden)
    end
  end

  defp create_data_structure_tag(_) do
    data_structure_tag = fixture(:data_structure_tag)
    %{data_structure_tag: data_structure_tag}
  end
end
