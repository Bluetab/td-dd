defmodule TdDdWeb.CommentControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdDd.Comments
  alias TdDd.Comments.Comment
  alias TdDd.Permissions.MockPermissionResolver
  alias TdDdWeb.ApiServices.MockTdAuditService
  alias TdDdWeb.ApiServices.MockTdAuthService

  @create_attrs %{
    content: "some content",
    resource_id: 42,
    resource_type: "some resource_type",
    user_id: 42
  }

  @structure_comment_attrs %{content: "some content", resource_type: "Structure", user_id: 42}

  @data_structure_attrs %{
    description: "some description",
    group: "some group",
    last_change_by: 42,
    name: "some name",
    external_id: "whatever external_id"
  }
  @update_attrs %{
    content: "some updated content",
    resource_id: 43,
    resource_type: "some updated resource_type",
    user_id: 43
  }
  @invalid_attrs %{content: nil, resource_id: nil, resource_type: nil, user_id: nil}

  def fixture(:comment) do
    {:ok, comment} = Comments.create_comment(@create_attrs)
    comment
  end

  setup_all do
    start_supervised(MockTdAuthService)
    start_supervised(MockTdAuditService)
    start_supervised(MockPermissionResolver)
    :ok
  end

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  @admin_user_name "app-admin"

  describe "index" do
    @tag authenticated_user: @admin_user_name
    test "lists all comments", %{conn: conn} do
      conn = get(conn, Routes.comment_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create comment" do
    @tag authenticated_user: @admin_user_name
    test "renders comment when data is valid", %{conn: conn} do
      assert %{"data" => %{"id" => id}} =
               conn
               |> post(Routes.comment_path(conn, :create), comment: @create_attrs)
               |> json_response(:created)

      assert %{"data" => data} =
               conn
               |> get(Routes.comment_path(conn, :show, id))
               |> json_response(:ok)

      assert %{
               "id" => id,
               "content" => "some content",
               "resource_id" => 42,
               "resource_type" => "some resource_type"
             } = data
    end

    @tag authenticated_user: @admin_user_name
    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.comment_path(conn, :create), comment: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end

    @tag authenticated_user: @admin_user_name
    test "renders comment related to a Data Structure", %{conn: conn} do
      system = insert(:system)
      system_id = system |> Map.get(:id)
      data_structure_attrs = Map.merge(@data_structure_attrs, %{system_id: system_id})

      assert %{"data" => %{"id" => data_structure_id}} =
               conn
               |> post(Routes.data_structure_path(conn, :create),
                 data_structure: data_structure_attrs
               )
               |> json_response(:created)

      comment_create_attrs = Map.put(@structure_comment_attrs, :resource_id, data_structure_id)

      assert %{"data" => %{"id" => id}} =
               conn
               |> post(Routes.comment_path(conn, :create), comment: comment_create_attrs)
               |> json_response(:created)

      assert %{"data" => data} =
               conn
               |> get(
                 Routes.data_structure_comment_path(
                   conn,
                   :get_comment_data_structure,
                   comment_create_attrs.resource_id
                 )
               )
               |> json_response(:ok)

      assert %{
               "id" => id,
               "content" => "some content",
               "resource_id" => data_structure_id,
               "resource_type" => "Structure"
             } = data
    end
  end

  describe "update comment" do
    setup [:create_comment]

    @tag authenticated_user: @admin_user_name
    test "renders comment when data is valid", %{conn: conn, comment: %Comment{id: id} = comment} do
      assert %{"data" => %{"id" => ^id}} =
               conn
               |> put(Routes.comment_path(conn, :update, comment), comment: @update_attrs)
               |> json_response(:ok)

      assert %{"data" => data} =
               conn
               |> get(Routes.comment_path(conn, :show, id))
               |> json_response(:ok)

      assert data == %{
               "id" => id,
               "content" => "some updated content",
               "resource_id" => 43,
               "resource_type" => "some updated resource_type",
               "user_id" => 43
             }
    end

    @tag authenticated_user: @admin_user_name
    test "renders errors when data is invalid", %{conn: conn, comment: comment} do
      conn = put(conn, Routes.comment_path(conn, :update, comment), comment: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete comment" do
    setup [:create_comment]

    @tag authenticated_user: @admin_user_name
    test "deletes chosen comment", %{conn: conn, comment: comment} do
      assert conn
             |> delete(Routes.comment_path(conn, :delete, comment))
             |> response(:no_content)

      assert_error_sent(:not_found, fn ->
        get(conn, Routes.comment_path(conn, :show, comment))
      end)
    end
  end

  defp create_comment(_) do
    comment = fixture(:comment)
    {:ok, comment: comment}
  end
end
