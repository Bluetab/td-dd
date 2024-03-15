defmodule TdDdWeb.GrantControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdDd.Grants.Grant

  @moduletag sandbox: :shared

  @user_id 123_456
  @create_attrs %{
    detail: %{},
    end_date: "2010-04-17",
    start_date: "2010-04-17",
    user_id: @user_id,
    source_user_name: "some source_user_name"
  }
  @update_attrs %{
    detail: %{},
    end_date: "2011-05-18",
    start_date: "2011-05-18",
    source_user_name: "other source_user_name"
  }
  @invalid_attrs %{detail: nil, end_date: nil, start_date: nil}

  setup do
    start_supervised!(TdDd.Search.StructureEnricher)
    CacheHelpers.insert_user(id: @user_id)
    :ok
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

    @tag authentication: [permissions: [:view_data_structure, :manage_grants]]
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
               "source_user_name" => "some source_user_name",
               "user_id" => @user_id
             } = data
    end

    @tag authentication: [permissions: [:manage_grants]]
    test "user with permissions cannot create a grant with a structure in other domain", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{external_id: data_structure_external_id} =
        insert(:data_structure, domain_ids: [domain_id + 1])

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
    setup :create_data_structure

    @tag authentication: [role: "admin"]
    test "can show grant", %{conn: conn, grant: %{id: id}, swagger_schema: schema} do
      assert %{"data" => %{"id" => ^id}} =
               conn
               |> get(Routes.grant_path(conn, :show, id))
               |> validate_resp_schema(schema, "GrantResponse")
               |> json_response(:ok)
    end

    @tag authentication: [permissions: [:view_grants, :view_data_structure]]
    test "user with permissions can show grant", %{conn: conn, grant: %{id: id}} do
      conn = get(conn, Routes.grant_path(conn, :show, id))

      assert %{"id" => ^id} = json_response(conn, :ok)["data"]
    end

    @tag authentication: [role: "non_admin"]
    test "user without view grant permission cannot show grant", %{conn: conn, grant: %{id: id}} do
      conn = get(conn, Routes.grant_path(conn, :show, id))

      assert json_response(conn, :forbidden)["errors"] != %{}
    end

    # Any permission so that own grant instead of foreign grant is created
    @tag authentication: [role: "non_admin", permissions: [:view_domain]]
    test "user without view grant permissions can show its own grant", %{
      conn: conn,
      grant: %{id: id}
    } do
      conn = get(conn, Routes.grant_path(conn, :show, id))
      assert %{"id" => ^id} = json_response(conn, :ok)["data"]
    end

    @tag authentication: [permissions: [:view_grants]]
    test "user with permissions cannot show a grant with structure in other domain", %{conn: conn} do
      %{id: id} = insert(:grant)
      conn = get(conn, Routes.grant_path(conn, :show, id))

      assert json_response(conn, :forbidden)["errors"] != %{}
    end

    @tag authentication: [permissions: [:view_grants, :view_data_structure]]
    test "grant has current version name", %{
      conn: conn,
      data_structure: %{id: data_structure_id} = data_structure
    } do
      name = "foo"
      insert(:data_structure_version, data_structure_id: data_structure_id, name: name)
      %{id: id} = insert(:grant, data_structure: data_structure)

      assert %{"data" => data} =
               conn
               |> get(Routes.grant_path(conn, :show, id))
               |> json_response(:ok)

      assert %{"id" => ^id, "data_structure_version" => %{"name" => ^name}} = data
    end

    @tag authentication: [
           permissions: [:view_grants, :view_data_structure, :manage_grant_removal]
         ]
    test "user with `manage_grant_removal` permissions has actions to mark/unmark grant pending removal on show",
         %{conn: conn, grant: %{id: id}} do
      assert %{"_actions" => actions} =
               get(conn, Routes.grant_path(conn, :show, id))
               |> json_response(:ok)

      assert %{"manage_grant_removal" => %{}} = actions
    end

    @tag authentication: [
           permissions: [:view_grants, :view_data_structure]
         ]
    test "user withouth `manage_grant_removal` premissions has not actions to remove grant on show",
         %{conn: conn, grant: %{id: id}} do
      assert %{"_actions" => %{}} =
               get(conn, Routes.grant_path(conn, :show, id))
               |> json_response(:ok)
    end

    @tag authentication: [
           permissions: [:view_grants, :view_data_structure, :create_foreign_grant_request]
         ]
    test "user with create_foreign_grant_request permission in grant domain can update a grant
          where granted user has allow_foreign_grant_request permission on the same domain",
         %{conn: conn, domain: %{id: domain_id}} do
      %{id: granted_user_id} = CacheHelpers.insert_user()
      grant_receiver_role = "granted_role"
      CacheHelpers.put_permission_on_role("allow_foreign_grant_request", grant_receiver_role)
      CacheHelpers.insert_acl(domain_id, grant_receiver_role, [granted_user_id])

      data_structure = insert(:data_structure, domain_ids: [domain_id])

      %{id: grant_id} = insert(:grant, data_structure: data_structure, user_id: granted_user_id)

      assert %{"_actions" => actions} =
               conn
               |> get(Routes.grant_path(conn, :show, grant_id))
               |> json_response(:ok)

      assert actions == %{"update" => %{}}
    end

    @tag authentication: [
           permissions: [:create_foreign_grant_request]
         ]
    test "user without create_foreign_grant_request permission in grant domain can't update a grant
        where granted user has allow_foreign_grant_request permission on the same domain",
         %{conn: conn, claims: claims} do
      %{id: domain_id} = CacheHelpers.insert_domain()
      %{id: granted_user_id} = CacheHelpers.insert_user()
      grant_receiver_role = "granted_role"
      CacheHelpers.put_permission_on_role("allow_foreign_grant_request", grant_receiver_role)
      CacheHelpers.insert_acl(domain_id, grant_receiver_role, [granted_user_id])

      CacheHelpers.put_session_permissions(claims, domain_id, [
        "view_data_structure",
        "view_grants"
      ])

      data_structure = insert(:data_structure, domain_ids: [domain_id])

      %{id: grant_id} = insert(:grant, data_structure: data_structure, user_id: granted_user_id)

      assert %{"_actions" => actions} =
               conn
               |> get(Routes.grant_path(conn, :show, grant_id))
               |> json_response(:ok)

      assert actions == %{}
    end

    @tag authentication: [
           permissions: [:view_grants, :view_data_structure, :create_foreign_grant_request]
         ]
    test "user with create_foreign_grant_request permission in grant domain can not update a grant
        where granted user has not allow_foreign_grant_request permission on the same domain",
         %{conn: conn, domain: %{id: domain_id}} do
      %{id: granted_user_id} = CacheHelpers.insert_user()

      data_structure = insert(:data_structure, domain_ids: [domain_id])

      %{id: grant_id} = insert(:grant, data_structure: data_structure, user_id: granted_user_id)

      assert %{"_actions" => actions} =
               conn
               |> get(Routes.grant_path(conn, :show, grant_id))
               |> json_response(:ok)

      assert actions == %{}
    end

    @tag authentication: [role: "admin"]
    test "show grantable grant actions if _grantable classification", %{conn: conn} do
      %{id: id, data_structure_id: ds_id} = insert(:grant)

      %{id: dsv_id} = insert(:data_structure_version, data_structure_id: ds_id)

      insert(:structure_classification,
        name: "_grantable",
        class: "grantable_database",
        data_structure_version_id: dsv_id
      )

      %{"_actions" => actions} =
        conn
        |> get(Routes.grant_path(conn, :show, id))
        |> json_response(:ok)

      assert %{
               "manage_grant_removal" => %{},
               "manage_grant_removal_request" => %{},
               "update" => %{}
             } = actions
    end

    @tag authentication: [role: "admin"]
    test "don't show grantable grant actions if not _grantable classification", %{conn: conn} do
      %{id: id, data_structure_id: ds_id} = insert(:grant)

      insert(:data_structure_version, data_structure_id: ds_id)

      %{"_actions" => actions} =
        conn
        |> get(Routes.grant_path(conn, :show, id))
        |> json_response(:ok)

      assert %{} == actions
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

    @tag authentication: [permissions: [:manage_grants, :view_data_structure]]
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

    @tag authentication: [
           permissions: [:manage_grant_removal, :view_grants, :view_data_structure]
         ]
    test "user with permissions can mark grant as pending removal", %{
      conn: conn,
      grant: %Grant{id: id} = grant
    } do
      assert %{"data" => %{"id" => ^id}} =
               conn
               |> put(Routes.grant_path(conn, :update, grant), action: "mark_pending_removal")
               |> json_response(:ok)

      assert %{"data" => data} =
               conn
               |> get(Routes.grant_path(conn, :show, id))
               |> json_response(:ok)

      assert %{
               "id" => ^id,
               "pending_removal" => true
             } = data
    end

    @tag authentication: [role: "non_admin", permissions: [:view_domain]]
    test "user without permissions cannot mark pending removal of own grant", %{
      conn: conn,
      grant: grant
    } do
      assert conn
             |> put(Routes.grant_path(conn, :update, grant), action: "mark_pending_removal")
             |> json_response(:forbidden)
    end

    @tag authentication: [role: "non_admin", permissions: [:view_domain]]
    test "user without permissions cannot cancel removal of own grant", %{
      conn: conn,
      grant: grant
    } do
      assert conn
             |> put(Routes.grant_path(conn, :update, grant), action: "unmark_pending_removal")
             |> json_response(:forbidden)
    end

    @tag authentication: [role: "admin"]
    test "set_removed action will update pending_removal and end_date properties", %{
      conn: conn,
      grant: %Grant{id: id} = grant
    } do
      assert %{"data" => %{"id" => ^id}} =
               conn
               |> put(Routes.grant_path(conn, :update, grant),
                 grant: %{
                   pending_removal: true,
                   end_date: nil
                 }
               )
               |> json_response(:ok)

      assert %{
               "data" => %{
                 "end_date" => nil,
                 "pending_removal" => true
               }
             } =
               conn
               |> get(Routes.grant_path(conn, :show, id))
               |> json_response(:ok)

      assert %{"data" => %{"id" => ^id}} =
               conn
               |> put(Routes.grant_path(conn, :update, grant), action: "set_removed")
               |> json_response(:ok)

      assert %{
               "data" => %{
                 "end_date" => end_date,
                 "pending_removal" => pending_removal
               }
             } =
               conn
               |> get(Routes.grant_path(conn, :show, id))
               |> json_response(:ok)

      assert not is_nil(end_date)
      assert not pending_removal
    end

    @tag authentication: [permissions: [:manage_grants]]
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

      assert_error_sent :not_found, fn ->
        get(conn, Routes.grant_path(conn, :show, grant))
      end
    end

    @tag authentication: [permissions: [:manage_grants, :view_data_structure]]
    test "user with permissions can delete grant", %{conn: conn, grant: grant} do
      assert conn
             |> delete(Routes.grant_path(conn, :delete, grant))
             |> response(:no_content)

      assert_error_sent :not_found, fn ->
        get(conn, Routes.grant_path(conn, :show, grant))
      end
    end

    @tag authentication: [permissions: [:manage_grants, :view_data_structure]]
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
        [data_structure: insert(:data_structure, domain_ids: [domain_id])]

      _ ->
        [data_structure: insert(:data_structure)]
    end
  end

  defp create_grant(context) do
    grant =
      case context do
        %{domain: %{id: domain_id}, claims: %{user_id: user_id}} ->
          data_structure = insert(:data_structure, domain_ids: [domain_id])
          insert(:grant, data_structure: data_structure, user_id: user_id)

        _ ->
          insert(:grant)
      end

    [grant: grant]
  end
end
