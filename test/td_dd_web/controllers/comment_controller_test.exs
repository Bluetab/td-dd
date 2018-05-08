defmodule TdDdWeb.CommentControllerTest do
  use TdDdWeb.ConnCase
  import TdDdWeb.Authentication, only: :functions

  alias TdDd.Comments
  alias TdDd.Comments.Comment
  alias TdDdWeb.ApiServices.MockTdAuthService

  @create_attrs %{content: "some content", resource_id: 42, resource_type: "some resource_type", user_id: 42}
  @update_attrs %{content: "some updated content", resource_id: 43, resource_type: "some updated resource_type", user_id: 43}
  @invalid_attrs %{content: nil, resource_id: nil, resource_type: nil, user_id: nil}

  def fixture(:comment) do
    {:ok, comment} = Comments.create_comment(@create_attrs)
    comment
  end

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
    test "lists all comments", %{conn: conn} do
      conn = get conn, comment_path(conn, :index)
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "create comment" do
    @tag authenticated_user: @admin_user_name
    test "renders comment when data is valid", %{conn: conn} do
      conn = post conn, comment_path(conn, :create), comment: @create_attrs
      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = recycle_and_put_headers(conn)

      conn = get conn, comment_path(conn, :show, id)
      assert json_response(conn, 200)["data"] == %{
        "id" => id,
        "content" => "some content",
        "resource_id" => 42,
        "resource_type" => "some resource_type",
        "user_id" => 42}
    end

    @tag authenticated_user: @admin_user_name
    test "renders errors when data is invalid", %{conn: conn} do
      conn = post conn, comment_path(conn, :create), comment: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "update comment" do
    setup [:create_comment]

    @tag authenticated_user: @admin_user_name
    test "renders comment when data is valid", %{conn: conn, comment: %Comment{id: id} = comment} do
      conn = put conn, comment_path(conn, :update, comment), comment: @update_attrs
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = recycle_and_put_headers(conn)

      conn = get conn, comment_path(conn, :show, id)
      assert json_response(conn, 200)["data"] == %{
        "id" => id,
        "content" => "some updated content",
        "resource_id" => 43,
        "resource_type" => "some updated resource_type",
        "user_id" => 43}
    end

    @tag authenticated_user: @admin_user_name
    test "renders errors when data is invalid", %{conn: conn, comment: comment} do
      conn = put conn, comment_path(conn, :update, comment), comment: @invalid_attrs
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete comment" do
    setup [:create_comment]

    @tag authenticated_user: @admin_user_name
    test "deletes chosen comment", %{conn: conn, comment: comment} do
      conn = delete conn, comment_path(conn, :delete, comment)
      assert response(conn, 204)

      conn = recycle_and_put_headers(conn)

      assert_error_sent 404, fn ->
        get conn, comment_path(conn, :show, comment)
      end
    end
  end

  defp create_comment(_) do
    comment = fixture(:comment)
    {:ok, comment: comment}
  end
end
