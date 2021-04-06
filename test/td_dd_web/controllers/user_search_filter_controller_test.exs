defmodule TdDdWeb.UserSearchFilterControllerTest do
  use TdDdWeb.ConnCase

  @create_attrs %{
    filters: %{country: ["Spa"]},
    name: "some name"
  }

  @invalid_attrs %{filters: nil, name: nil, user_id: nil}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index" do
    @tag authentication: [role: "admin"]
    test "lists all user_search_filters", %{conn: conn} do
      assert %{"data" => []} =
               conn
               |> get(Routes.user_search_filter_path(conn, :index))
               |> json_response(:ok)
    end
  end

  describe "index by user" do
    @tag authentication: [role: "admin"]
    test "lists current user user_search_filters", %{conn: conn, claims: %{user_id: user_id}} do
      insert(:user_search_filter, user_id: 1)
      insert(:user_search_filter, user_id: 2)
      insert(:user_search_filter, name: "a", user_id: user_id)
      insert(:user_search_filter, name: "b", user_id: user_id)

      assert %{"data" => data} =
               conn
               |> get(Routes.user_search_filter_path(conn, :index_by_user))
               |> json_response(:ok)

      assert [%{"user_id" => ^user_id}, %{"user_id" => ^user_id}] = data
    end
  end

  describe "create user_search_filter" do
    @tag authentication: [role: "admin"]
    test "renders user_search_filter when data is valid", %{conn: conn} do
      assert %{"data" => %{"id" => id}} =
               conn
               |> post(Routes.user_search_filter_path(conn, :create),
                 user_search_filter: @create_attrs
               )
               |> json_response(:created)

      assert %{"data" => data} =
               conn
               |> get(Routes.user_search_filter_path(conn, :show, id))
               |> json_response(:ok)

      assert %{
               "id" => _id,
               "filters" => %{},
               "name" => "some name",
               "user_id" => _user_id
             } = data
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{conn: conn} do
      assert %{"errors" => %{} = errors} =
               conn
               |> post(Routes.user_search_filter_path(conn, :create),
                 user_search_filter: @invalid_attrs
               )
               |> json_response(:unprocessable_entity)

      assert errors != %{}
    end
  end

  describe "delete user_search_filter" do
    @tag authentication: [role: "admin"]
    test "deletes chosen user_search_filter", %{
      conn: conn
    } do
      assert %{"data" => %{"id" => id}} =
               conn
               |> post(Routes.user_search_filter_path(conn, :create),
                 user_search_filter: @create_attrs
               )
               |> json_response(:created)

      assert conn
             |> delete(Routes.user_search_filter_path(conn, :delete, id))
             |> response(:no_content)

      assert conn
             |> get(Routes.user_search_filter_path(conn, :show, id))
             |> response(:not_found)
    end
  end
end
