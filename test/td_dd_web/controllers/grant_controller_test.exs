defmodule TdDdWeb.GrantControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdDd.Grants.Grant

  @user_id 123_456
  @create_attrs %{
    detail: %{},
    end_date: "2010-04-17",
    start_date: "2010-04-17",
    user_id: @user_id
  }
  @update_attrs %{
    detail: %{},
    end_date: "2011-05-18",
    start_date: "2011-05-18"
  }
  @invalid_attrs %{detail: nil, end_date: nil, start_date: nil}

  setup %{conn: conn} do
    CacheHelpers.insert_user(id: @user_id)
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "create grant" do
    setup :create_data_structure

    @tag authentication: [role: "admin"]
    test "renders grant when data is valid", %{
      conn: conn,
      data_structure: %{id: data_structure_id, external_id: data_structure_external_id},
      swagger_schema: schema
    } do
      insert(:data_structure_version, data_structure_id: data_structure_id)

      assert %{"data" => %{"id" => id}} =
               conn
               |> post(
                 Routes.data_structure_grant_path(conn, :create, data_structure_external_id),
                 grant: @create_attrs
               )
               |> validate_resp_schema(schema, "GrantResponse")
               |> json_response(:created)

      assert %{"data" => data} =
               conn
               |> get(Routes.grant_path(conn, :show, id))
               |> validate_resp_schema(schema, "GrantResponse")
               |> json_response(:ok)

      assert %{
               "id" => ^id,
               "detail" => %{},
               "end_date" => "2010-04-17",
               "start_date" => "2010-04-17",
               "user_id" => @user_id,
               "data_structure" => %{
                 "id" => ^data_structure_id,
                 "external_id" => ^data_structure_external_id
               },
               "system" => %{"external_id" => _, "id" => _, "name" => _}
             } = data
    end

    @tag authentication: [role: "non_admin", permissions: [:manage_grants]]
    test "user with permissions can create a grant", %{
      conn: conn,
      data_structure: %{external_id: data_structure_external_id},
      swagger_schema: schema
    } do
      assert %{"data" => %{"id" => id}} =
               conn
               |> post(
                 Routes.data_structure_grant_path(conn, :create, data_structure_external_id),
                 grant: @create_attrs
               )
               |> validate_resp_schema(schema, "GrantResponse")
               |> json_response(:created)

      assert %{"data" => data} =
               conn
               |> get(Routes.grant_path(conn, :show, id))
               |> validate_resp_schema(schema, "GrantResponse")
               |> json_response(:ok)

      assert %{
               "id" => ^id,
               "detail" => %{},
               "end_date" => "2010-04-17",
               "start_date" => "2010-04-17",
               "user_id" => @user_id
             } = data
    end

    @tag authentication: [role: "non_admin", permissions: [:manage_grants]]
    test "user with permissions cannot create a grant with a structure in other domain", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{external_id: data_structure_external_id} =
        insert(:data_structure, domain_id: domain_id + 1)

      assert %{"errors" => %{} = errors} =
               conn
               |> post(
                 Routes.data_structure_grant_path(conn, :create, data_structure_external_id),
                 grant: @create_attrs
               )
               |> json_response(:forbidden)

      refute errors == %{}
    end

    @tag authentication: [role: "non_admin"]
    test "user without permissions can't create a grant", %{
      conn: conn,
      data_structure: %{external_id: data_structure_external_id}
    } do
      assert %{"errors" => %{} = errors} =
               conn
               |> post(
                 Routes.data_structure_grant_path(conn, :create, data_structure_external_id),
                 grant: @create_attrs
               )
               |> json_response(:forbidden)

      refute errors == %{}
    end

    @tag authentication: [role: "admin"]
    test "grant will not be created with invalid structure", %{conn: conn} do
      assert %{"message" => "DataStructure"} =
               conn
               |> post(Routes.data_structure_grant_path(conn, :create, "invalid_external_id"),
                 grant: @create_attrs
               )
               |> json_response(:not_found)
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{
      conn: conn,
      data_structure: %{external_id: data_structure_external_id}
    } do
      assert %{"errors" => %{} = errors} =
               conn
               |> post(
                 Routes.data_structure_grant_path(conn, :create, data_structure_external_id),
                 grant: @invalid_attrs
               )
               |> json_response(:unprocessable_entity)

      refute errors == %{}
    end
  end

  describe "show grant" do
    setup :create_grant

    @tag authentication: [role: "admin"]
    test "can show grant", %{conn: conn, grant: %{id: id}, swagger_schema: schema} do
      assert %{"data" => %{"id" => ^id}} =
               conn
               |> get(Routes.grant_path(conn, :show, id))
               |> validate_resp_schema(schema, "GrantResponse")
               |> json_response(:ok)
    end

    @tag authentication: [role: "non_admin", permissions: [:view_grants]]
    test "user with permissions can show grant", %{conn: conn, grant: %{id: id}} do
      conn = get(conn, Routes.grant_path(conn, :show, id))

      assert %{"id" => ^id} = json_response(conn, :ok)["data"]
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

      assert %{"id" => ^id} = json_response(conn, :ok)["data"]
    end

    @tag authentication: [role: "non_admin", permissions: [:view_grants]]
    test "user with permissions cannot show a grant with structure in other domain", %{conn: conn} do
      %{id: id} = insert(:grant)
      conn = get(conn, Routes.grant_path(conn, :show, id))

      assert json_response(conn, :forbidden)["errors"] != %{}
    end
  end

  describe "update grant" do
    setup :create_grant

    @tag authentication: [role: "admin"]
    test "renders grant when data is valid", %{
      conn: conn,
      grant: %Grant{id: id, user_id: user_id} = grant,
      swagger_schema: schema
    } do
      assert %{"data" => %{"id" => ^id}} =
               conn
               |> put(Routes.grant_path(conn, :update, grant), grant: @update_attrs)
               |> json_response(:ok)

      assert %{"data" => data} =
               conn
               |> get(Routes.grant_path(conn, :show, id))
               |> validate_resp_schema(schema, "GrantResponse")
               |> json_response(:ok)

      assert %{
               "id" => ^id,
               "detail" => %{},
               "end_date" => "2011-05-18",
               "start_date" => "2011-05-18",
               "user_id" => ^user_id
             } = data
    end

    @tag authentication: [role: "non_admin", permissions: [:manage_grants]]
    test "user with permissions can update a grant", %{
      conn: conn,
      grant: %Grant{id: id} = grant
    } do
      assert %{"data" => %{"id" => ^id}} =
               conn
               |> put(Routes.grant_path(conn, :update, grant), grant: @update_attrs)
               |> json_response(:ok)

      assert %{"data" => data} =
               conn
               |> get(Routes.grant_path(conn, :show, id))
               |> json_response(:ok)

      assert %{
               "id" => ^id,
               "detail" => %{},
               "end_date" => "2011-05-18",
               "start_date" => "2011-05-18"
             } = data
    end

    @tag authentication: [role: "non_admin", permissions: [:manage_grants]]
    test "user with permissions cannot update a grant with a structure in other domain", %{
      conn: conn
    } do
      grant = insert(:grant)

      assert %{"errors" => %{} = errors} =
               conn
               |> put(Routes.grant_path(conn, :update, grant), grant: @update_attrs)
               |> json_response(:forbidden)

      assert %{"detail" => _} = errors
    end

    @tag authentication: [role: "non_admin"]
    test "user without permissions cannot update a grant", %{conn: conn, grant: grant} do
      assert %{"errors" => %{} = errors} =
               conn
               |> put(Routes.grant_path(conn, :update, grant), grant: @update_attrs)
               |> json_response(:forbidden)

      assert %{"detail" => _} = errors
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{conn: conn, grant: grant} do
      assert %{"errors" => %{} = errors} =
               conn
               |> put(Routes.grant_path(conn, :update, grant), grant: @invalid_attrs)
               |> json_response(:unprocessable_entity)

      refute errors == %{}
    end
  end

  describe "delete grant" do
    setup :create_grant

    @tag authentication: [role: "admin"]
    test "deletes chosen grant", %{conn: conn, grant: grant} do
      assert conn
             |> delete(Routes.grant_path(conn, :delete, grant))
             |> response(:no_content)

      assert_error_sent 404, fn ->
        get(conn, Routes.grant_path(conn, :show, grant))
      end
    end

    @tag authentication: [role: "non_admin", permissions: [:manage_grants]]
    test "user with permissions can delete grant", %{conn: conn, grant: grant} do
      assert conn
             |> delete(Routes.grant_path(conn, :delete, grant))
             |> response(:no_content)

      assert_error_sent 404, fn ->
        get(conn, Routes.grant_path(conn, :show, grant))
      end
    end

    @tag authentication: [role: "non_admin", permissions: [:manage_grants]]
    test "user with permissions cannot delete grant with structure in other domain", %{conn: conn} do
      grant = insert(:grant)

      assert %{"errors" => %{} = errors} =
               conn
               |> delete(Routes.grant_path(conn, :delete, grant))
               |> json_response(:forbidden)

      refute errors == %{}
    end

    @tag authentication: [role: "non_admin"]
    test "user without permissions cannot delete grant", %{conn: conn, grant: grant} do
      assert %{"errors" => %{} = errors} =
               conn
               |> delete(Routes.grant_path(conn, :delete, grant))
               |> json_response(:forbidden)

      refute errors == %{}
    end
  end

  defp create_data_structure(context) do
    case context do
      %{domain: %{id: domain_id}} ->
        [data_structure: insert(:data_structure, domain_id: domain_id)]

      _ ->
        [data_structure: insert(:data_structure)]
    end
  end

  defp create_grant(context) do
    grant =
      case context do
        %{domain: %{id: domain_id}} ->
          data_structure = insert(:data_structure, domain_id: domain_id)
          insert(:grant, data_structure: data_structure)

        _ ->
          insert(:grant)
      end

    [grant: grant]
  end
end
