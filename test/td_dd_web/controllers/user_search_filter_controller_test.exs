defmodule TdDdWeb.UserSearchFilterControllerTest do
  use TdDdWeb.ConnCase

  @create_attrs %{
    filters: %{country: ["Spa"]},
    name: "some name",
    scope: "rule_implementation"
  }

  @invalid_attrs %{filters: nil, name: nil, user_id: nil, scope: "invalid"}

  describe "index" do
    @tag authentication: [role: "admin"]
    test "lists all user_search_filters", %{conn: conn} do
      assert %{"data" => []} =
               conn
               |> get(Routes.user_search_filter_path(conn, :index))
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "lists all user_search_filters filtered by scope", %{conn: conn} do
      %{id: id} = insert(:user_search_filter, scope: "rule")
      insert(:user_search_filter, scope: "rule_implementation")

      assert %{"data" => [%{"id" => ^id}]} =
               conn
               |> get(Routes.user_search_filter_path(conn, :index), %{"scope" => "rule"})
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

    @tag authentication: [role: "admin"]
    test "lists current user user_search_filters by scope", %{
      conn: conn,
      claims: %{user_id: user_id}
    } do
      %{id: id} = insert(:user_search_filter, name: "a", user_id: user_id, scope: "rule")
      insert(:user_search_filter, name: "b", user_id: user_id, scope: "rule_implementation")

      assert %{"data" => data} =
               conn
               |> get(Routes.user_search_filter_path(conn, :index_by_user), %{"scope" => "rule"})
               |> json_response(:ok)

      assert [%{"id" => ^id}] = data
    end

    @tag authentication: [user_name: "non_admin", permissions: ["view_quality_rule"]]
    test "lists current user user_search_filters with global filters", %{
      conn: conn,
      claims: %{user_id: user_id}
    } do
      %{id: id1} = insert(:user_search_filter, scope: "rule", name: "a", user_id: user_id)
      %{id: id2} = insert(:user_search_filter, scope: "rule", name: "b", is_global: true)
      insert(:user_search_filter, scope: "rule", name: "c", is_global: false)

      assert %{"data" => data} =
               conn
               |> get(Routes.user_search_filter_path(conn, :index_by_user), %{"scope" => "rule"})
               |> json_response(:ok)

      assert_lists_equal(data, [id1, id2], &(&1["id"] == &2))
    end

    @tag authentication: [user_name: "non_admin", permissions: ["view_data_structure"]]
    test "global filters with taxonomy will only appear for users with permission on any filter domain",
         %{
           conn: conn,
           claims: %{user_id: user_id},
           domain: %{id: domain_id}
         } do
      %{id: id1} = insert(:user_search_filter, scope: "data_structure", user_id: user_id)

      %{id: id2} =
        insert(:user_search_filter,
          scope: "data_structure",
          filters: %{"taxonomy" => [domain_id]},
          is_global: true
        )

      insert(:user_search_filter,
        scope: "data_structure",
        filters: %{"taxonomy" => [domain_id + 1]},
        is_global: true
      )

      insert(:user_search_filter, scope: "data_structure", is_global: false)

      assert %{"data" => data} =
               conn
               |> get(Routes.user_search_filter_path(conn, :index_by_user), %{
                 "scope" => "data_structure"
               })
               |> json_response(:ok)

      assert_lists_equal(data, [id1, id2], &(&1["id"] == &2))
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
               "user_id" => _user_id,
               "scope" => "rule_implementation",
               "is_global" => false
             } = data
    end

    @tag authentication: [user_name: "non_admin"]
    test "non admin users can create filters", %{conn: conn} do
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
               "user_id" => _user_id,
               "scope" => "rule_implementation",
               "is_global" => false
             } = data
    end

    @tag authentication: [user_name: "non_admin"]
    test "non admin users cannot create global filters", %{conn: conn} do
      global_attrs = Map.put(@create_attrs, :is_global, true)

      assert conn
             |> post(Routes.user_search_filter_path(conn, :create),
               user_search_filter: global_attrs
             )
             |> json_response(:forbidden)
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

    @tag authentication: [role: "admin"]
    test "admin not owner deletes chosen user_search_filter", %{
      conn: conn
    } do
      other_admin_user = build(:user, role: "admin")
      %{id: id} = insert(:user_search_filter, user_id: other_admin_user.id)

      assert conn
             |> delete(Routes.user_search_filter_path(conn, :delete, id))
             |> response(:no_content)

      assert conn
             |> get(Routes.user_search_filter_path(conn, :show, id))
             |> response(:not_found)
    end
  end
end
