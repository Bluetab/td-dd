defmodule TdDdWeb.RelationTypeControllerTest do
  use TdDdWeb.ConnCase

  alias TdDd.DataStructures.RelationType
  alias TdDd.DataStructures.RelationTypes

  @create_attrs %{
    description: "some description",
    name: "some name"
  }
  @update_attrs %{
    description: "some updated description",
    name: "some updated name"
  }
  @invalid_attrs %{description: nil, name: nil}

  setup_all do
    start_supervised(TdDd.Permissions.MockPermissionResolver)
    :ok
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    @tag :admin_authenticated
    test "lists all relation_types", %{conn: conn} do
      assert %{"data" => data} =
               conn
               |> get(Routes.relation_type_path(conn, :index))
               |> json_response(:ok)

      assert [%{"description" => "Parent/Child", "id" => 1, "name" => "default"}] = data
    end
  end

  describe "create relation_type" do
    @tag :admin_authenticated
    test "renders relation_type when data is valid", %{conn: conn} do
      assert %{"data" => %{"id" => id}} =
               conn
               |> post(Routes.relation_type_path(conn, :create), relation_type: @create_attrs)
               |> json_response(:created)

      assert %{"data" => data} =
               conn
               |> get(Routes.relation_type_path(conn, :show, id))
               |> json_response(:ok)

      assert %{
               "id" => _id,
               "description" => "some description",
               "name" => "some name"
             } = data
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn} do
      assert %{"errors" => errors} =
               conn
               |> post(Routes.relation_type_path(conn, :create), relation_type: @invalid_attrs)
               |> json_response(:unprocessable_entity)

      assert errors
      assert errors != %{}
    end
  end

  describe "update relation_type" do
    setup [:create_relation_type]

    @tag :admin_authenticated
    test "renders relation_type when data is valid", %{
      conn: conn,
      relation_type: %RelationType{id: id} = relation_type
    } do
      assert %{"data" => %{"id" => ^id}} =
               conn
               |> put(Routes.relation_type_path(conn, :update, relation_type),
                 relation_type: @update_attrs
               )
               |> json_response(:ok)

      assert %{"data" => data} =
               conn
               |> get(Routes.relation_type_path(conn, :show, id))
               |> json_response(:ok)

      assert %{
               "id" => _id,
               "description" => "some updated description",
               "name" => "some updated name"
             } = data
    end

    @tag :admin_authenticated
    test "renders errors when data is invalid", %{conn: conn, relation_type: relation_type} do
      assert %{"errors" => errors} =
               conn
               |> put(Routes.relation_type_path(conn, :update, relation_type),
                 relation_type: @invalid_attrs
               )
               |> json_response(:unprocessable_entity)

      assert errors
      assert errors != %{}
    end
  end

  describe "delete relation_type" do
    setup [:create_relation_type]

    @tag :admin_authenticated
    test "deletes chosen relation_type", %{conn: conn, relation_type: relation_type} do
      assert conn
             |> delete(Routes.relation_type_path(conn, :delete, relation_type))
             |> response(:no_content)

      assert_error_sent :not_found, fn ->
        get(conn, Routes.relation_type_path(conn, :show, relation_type))
      end
    end
  end

  defp create_relation_type(_) do
    {:ok, relation_type} = RelationTypes.create_relation_type(@create_attrs)
    {:ok, relation_type: relation_type}
  end
end
