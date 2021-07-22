defmodule TdDdWeb.GrantControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdCache.UserCache
  alias TdDd.Grants.Grant

  @cache_user_id 42
  @cache_user_name "test_user_name"

  @create_attrs %{
    detail: %{},
    end_date: "2010-04-17T14:00:00.000000Z",
    start_date: "2010-04-17T14:00:00.000000Z",
    user_id: @cache_user_id
  }
  @update_attrs %{
    detail: %{},
    end_date: "2011-05-18T15:01:01.000000Z",
    start_date: "2011-05-18T15:01:01.000000Z",
    user_id: 43
  }
  @invalid_attrs %{detail: nil, end_date: nil, start_date: nil, user_id: @cache_user_id}

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "create grant" do
    setup assigns do
      UserCache.put(%{
        id: @cache_user_id,
        user_name: @cache_user_name,
        full_name: "foo"
      })

      on_exit(fn ->
        UserCache.delete(@create_attrs.user_id)
      end)

      case assigns do
        %{domain: %{id: domain_id}} ->
          [data_structure: insert(:data_structure, domain_id: domain_id)]

        _ ->
          [data_structure: insert(:data_structure)]
      end
    end

    @tag authentication: [role: "admin"]
    test "renders grant when data is valid", %{
      conn: conn,
      data_structure: %{id: data_structure_id, external_id: data_structure_external_id},
      swagger_schema: schema
    } do
      %{name: dsv_name} = insert(:data_structure_version, data_structure_id: data_structure_id)

      conn =
        post(conn, Routes.data_structure_grant_path(conn, :create, data_structure_external_id),
          grant: @create_attrs
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]

      assert %{
               "id" => ^id,
               "detail" => %{},
               "end_date" => "2010-04-17T14:00:00.000000Z",
               "start_date" => "2010-04-17T14:00:00.000000Z",
               "user_id" => @cache_user_id,
               "data_structure" => %{
                 "id" => ^data_structure_id,
                 "name" => ^dsv_name,
                 "external_id" => ^data_structure_external_id
               }
             } =
               conn
               |> get(Routes.grant_path(conn, :show, id))
               |> validate_resp_schema(schema, "GrantResponse")
               |> json_response(200)
               |> Map.get("data")
    end

    @tag authentication: [role: "non_admin", permissions: [:manage_grants]]
    test "user with permissions can create a grant", %{
      conn: conn,
      data_structure: %{external_id: data_structure_external_id}
    } do
      conn =
        post(conn, Routes.data_structure_grant_path(conn, :create, data_structure_external_id),
          grant: @create_attrs
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.grant_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "detail" => %{},
               "end_date" => "2010-04-17T14:00:00.000000Z",
               "start_date" => "2010-04-17T14:00:00.000000Z",
               "user_id" => @cache_user_id
             } = json_response(conn, 200)["data"]
    end

    @tag authentication: [role: "non_admin", permissions: [:manage_grants]]
    test "user with permissions cannot create a grant with a structure in other domain", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{external_id: data_structure_external_id} =
        insert(:data_structure, domain_id: domain_id + 1)

      conn =
        post(conn, Routes.data_structure_grant_path(conn, :create, data_structure_external_id),
          grant: @create_attrs
        )

      assert json_response(conn, :forbidden)["errors"] != %{}
    end

    @tag authentication: [role: "non_admin"]
    test "user without permissions can't create a grant", %{
      conn: conn,
      data_structure: %{external_id: data_structure_external_id}
    } do
      conn =
        post(conn, Routes.data_structure_grant_path(conn, :create, data_structure_external_id),
          grant: @create_attrs
        )

      assert json_response(conn, :forbidden)["errors"] != %{}
    end

    @tag authentication: [role: "admin"]
    test "grant will not be created with invalid structure", %{conn: conn} do
      conn =
        post(conn, Routes.data_structure_grant_path(conn, :create, "invalid_external_id"),
          grant: @create_attrs
        )

      assert json_response(conn, :not_found)["message"] == "DataStructure"
    end

    @tag authentication: [role: "admin"]
    test "grant will not be created with invalid user", %{
      conn: conn,
      data_structure: %{external_id: data_structure_external_id}
    } do
      attrs = Map.put(@create_attrs, :user_id, 888)

      conn =
        post(conn, Routes.data_structure_grant_path(conn, :create, data_structure_external_id),
          grant: attrs
        )

      assert json_response(conn, :not_found)["message"] == "User"
    end

    @tag authentication: [role: "admin"]
    test "it is possible to create a grant using the user's user_name", %{
      conn: conn,
      data_structure: %{external_id: data_structure_external_id}
    } do
      attrs =
        @create_attrs
        |> Map.delete(:user_id)
        |> Map.put(:user_name, @cache_user_name)

      conn =
        post(conn, Routes.data_structure_grant_path(conn, :create, data_structure_external_id),
          grant: attrs
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.grant_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "detail" => %{},
               "end_date" => "2010-04-17T14:00:00.000000Z",
               "start_date" => "2010-04-17T14:00:00.000000Z",
               "user_id" => @cache_user_id
             } = json_response(conn, 200)["data"]
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{
      conn: conn,
      data_structure: %{external_id: data_structure_external_id}
    } do
      conn =
        post(conn, Routes.data_structure_grant_path(conn, :create, data_structure_external_id),
          grant: @invalid_attrs
        )

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "show grant" do
    setup [:create_grant]

    @tag authentication: [role: "admin"]
    test "can show grant", %{conn: conn, grant: %{id: id}, swagger_schema: schema} do
      assert %{"id" => ^id} =
               conn
               |> get(Routes.grant_path(conn, :show, id))
               |> validate_resp_schema(schema, "GrantResponse")
               |> json_response(200)
               |> Map.get("data")
    end

    @tag authentication: [role: "non_admin", permissions: [:view_grants]]
    test "user with permissions can show grant", %{conn: conn, grant: %{id: id}} do
      conn = get(conn, Routes.grant_path(conn, :show, id))

      assert %{"id" => ^id} = json_response(conn, 200)["data"]
    end

    @tag authentication: [role: "non_admin"]
    test "user without permissions cannot show grant", %{conn: conn, grant: %{id: id}} do
      conn = get(conn, Routes.grant_path(conn, :show, id))

      assert json_response(conn, :forbidden)["errors"] != %{}
    end

    @tag authentication: [role: "non_admin"]
    test "user without permissions can show its own grant", %{
      conn: conn,
      claims: %{user_id: user_id}
    } do
      %{id: id} = insert(:grant, user_id: user_id)
      conn = get(conn, Routes.grant_path(conn, :show, id))

      assert %{"id" => ^id} = json_response(conn, 200)["data"]
    end

    @tag authentication: [role: "non_admin", permissions: [:view_grants]]
    test "user with permissions cannot show a grant with structure in other domain", %{conn: conn} do
      %{id: id} = insert(:grant)
      conn = get(conn, Routes.grant_path(conn, :show, id))

      assert json_response(conn, :forbidden)["errors"] != %{}
    end
  end

  describe "update grant" do
    setup [:create_grant]

    @tag authentication: [role: "admin"]
    test "renders grant when data is valid", %{
      conn: conn,
      grant: %Grant{id: id, user_id: user_id} = grant,
      swagger_schema: schema
    } do
      conn = put(conn, Routes.grant_path(conn, :update, grant), grant: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      assert %{
               "id" => ^id,
               "detail" => %{},
               "end_date" => "2011-05-18T15:01:01.000000Z",
               "start_date" => "2011-05-18T15:01:01.000000Z",
               "user_id" => ^user_id
             } =
               conn
               |> get(Routes.grant_path(conn, :show, id))
               |> validate_resp_schema(schema, "GrantResponse")
               |> json_response(200)
               |> Map.get("data")
    end

    @tag authentication: [role: "non_admin", permissions: [:manage_grants]]
    test "user with permissions can update a grant", %{
      conn: conn,
      grant: %Grant{id: id} = grant
    } do
      conn = put(conn, Routes.grant_path(conn, :update, grant), grant: @update_attrs)
      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.grant_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "detail" => %{},
               "end_date" => "2011-05-18T15:01:01.000000Z",
               "start_date" => "2011-05-18T15:01:01.000000Z"
             } = json_response(conn, 200)["data"]
    end

    @tag authentication: [role: "non_admin", permissions: [:manage_grants]]
    test "user with permissions cannot update a grant with a structure in other domain", %{
      conn: conn
    } do
      grant = insert(:grant)

      conn = put(conn, Routes.grant_path(conn, :update, grant), grant: @update_attrs)

      assert json_response(conn, :forbidden)["errors"] != %{}
    end

    @tag authentication: [role: "non_admin"]
    test "user without permissions cannot update a grant", %{
      conn: conn,
      grant: grant
    } do
      conn = put(conn, Routes.grant_path(conn, :update, grant), grant: @update_attrs)
      assert json_response(conn, :forbidden)["errors"] != %{}
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{conn: conn, grant: grant} do
      conn = put(conn, Routes.grant_path(conn, :update, grant), grant: @invalid_attrs)
      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete grant" do
    setup [:create_grant]

    @tag authentication: [role: "admin"]
    test "deletes chosen grant", %{conn: conn, grant: grant} do
      conn = delete(conn, Routes.grant_path(conn, :delete, grant))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.grant_path(conn, :show, grant))
      end
    end

    @tag authentication: [role: "non_admin", permissions: [:manage_grants]]
    test "user with permissions can delete grant", %{conn: conn, grant: grant} do
      conn = delete(conn, Routes.grant_path(conn, :delete, grant))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.grant_path(conn, :show, grant))
      end
    end

    @tag authentication: [role: "non_admin", permissions: [:manage_grants]]
    test "user with permissions cannot delete grant with structure in other domain", %{conn: conn} do
      grant = insert(:grant)
      conn = delete(conn, Routes.grant_path(conn, :delete, grant))
      assert json_response(conn, :forbidden)["errors"] != %{}
    end

    @tag authentication: [role: "non_admin"]
    test "user without permissions cannot delete grant", %{conn: conn, grant: grant} do
      conn = delete(conn, Routes.grant_path(conn, :delete, grant))
      assert json_response(conn, :forbidden)["errors"] != %{}
    end
  end

  defp create_grant(assigns) do
    grant =
      case assigns do
        %{domain: %{id: domain_id}} ->
          data_structure = insert(:data_structure, domain_id: domain_id)
          insert(:grant, data_structure: data_structure)

        _ ->
          insert(:grant)
      end

    %{grant: grant}
  end
end
