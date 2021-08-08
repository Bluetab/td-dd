defmodule TdDdWeb.GrantRequestGroupControllerTest do
  use TdDdWeb.ConnCase

  alias TdCache.TemplateCache
  alias TdCache.UserCache
  alias TdDd.Grants.GrantRequestGroup

  @cache_user_id 42
  @cache_user_name "test_user_name"

  @create_attrs %{
    request_date: "2010-04-17T14:00:00.000000Z",
    type: nil,
    user_id: @cache_user_id
  }
  @update_attrs %{
    request_date: "2011-05-18T15:01:01.000000Z",
    type: "some updated type",
    user_id: 43
  }
  @invalid_attrs %{request_date: nil, type: nil, user_id: nil}
  @template_name "grant_request_group_controller_test_template"

  setup %{conn: conn} do
    %{id: template_id} = template = build(:template, name: @template_name)
    data_structure = insert(:data_structure)
    {:ok, _} = TemplateCache.put(template, publish: false)
    on_exit(fn -> TemplateCache.delete(template_id) end)

    create_attrs =
      Map.put(@create_attrs, :requests, [%{"data_structure_id" => data_structure.id}])

    {:ok,
     conn: put_req_header(conn, "accept", "application/json"),
     data_structure: data_structure,
     create_attrs: create_attrs}
  end

  describe "index" do
    @tag authentication: [role: "admin"]
    test "lists all grant_request_groups", %{conn: conn} do
      conn = get(conn, Routes.grant_request_group_path(conn, :index))
      assert json_response(conn, 200)["data"] == []
    end

    @tag authentication: [user_name: "non_admin"]
    test "non admin user can only list own grant_request_groups", %{
      conn: conn,
      claims: %{user_id: user_id}
    } do
      insert(:grant_request_group)
      %{id: id} = insert(:grant_request_group, user_id: user_id)
      conn = get(conn, Routes.grant_request_group_path(conn, :index))
      assert [%{"id" => ^id}] = json_response(conn, 200)["data"]
    end
  end

  describe "show" do
    @tag authentication: [user_namer: "non_admin"]
    test "non admin user cannot show grant_request_group from other user", %{conn: conn} do
      %{id: id} = insert(:grant_request_group)
      conn = get(conn, Routes.grant_request_group_path(conn, :show, id))

      assert response(conn, :forbidden)
    end

    @tag authentication: [user_namer: "non_admin"]
    test "non admin user can show own grant_request_group", %{
      conn: conn,
      claims: %{user_id: user_id}
    } do
      %{id: id} = insert(:grant_request_group, user_id: user_id)
      conn = get(conn, Routes.grant_request_group_path(conn, :show, id))

      assert json_response(conn, 200)
    end
  end

  describe "create grant_request_group" do
    setup _ do
      UserCache.put(%{
        id: @cache_user_id,
        user_name: @cache_user_name,
        full_name: "foo"
      })

      on_exit(fn ->
        UserCache.delete(@create_attrs.user_id)
      end)
    end

    @tag authentication: [role: "admin"]
    test "renders grant_request_group when data is valid", %{
      conn: conn,
      create_attrs: create_attrs
    } do
      conn =
        post(conn, Routes.grant_request_group_path(conn, :create),
          grant_request_group: create_attrs
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.grant_request_group_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "request_date" => "2010-04-17T14:00:00.000000Z",
               "user_id" => @cache_user_id
             } = json_response(conn, 200)["data"]
    end

    @tag authentication: [user: "non_admin"]
    test "user without permission on structure cannot create grant_request_group", %{
      conn: conn,
      create_attrs: create_attrs
    } do
      conn =
        post(conn, Routes.grant_request_group_path(conn, :create),
          grant_request_group: create_attrs
        )

      assert response(conn, :forbidden)
    end

    @tag authentication: [user: "non_admin", permissions: [:create_grant_request]]
    test "user with permission on structure can create grant_request_group", %{
      conn: conn,
      domain: %{id: domain_id},
      claims: %{user_id: user_id}
    } do
      UserCache.put(%{
        id: user_id,
        user_name: "non_admin",
        full_name: "foo"
      })

      on_exit(fn ->
        UserCache.delete(@create_attrs.user_id)
      end)

      %{id: ds_id} = insert(:data_structure, domain_id: domain_id)

      attrs =
        @create_attrs
        |> Map.put(:requests, [%{"data_structure_id" => ds_id}])
        |> Map.put(:user_id, user_id)

      conn =
        post(conn, Routes.grant_request_group_path(conn, :create), grant_request_group: attrs)

      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.grant_request_group_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "request_date" => "2010-04-17T14:00:00.000000Z",
               "user_id" => ^user_id
             } = json_response(conn, 200)["data"]
    end

    @tag authentication: [user: "non_admin", permissions: [:create_grant_request]]
    test "user cannot create grant_request_group with distinct user_id", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{id: ds_id} = insert(:data_structure, domain_id: domain_id)

      attrs = Map.put(@create_attrs, :requests, [%{"data_structure_id" => ds_id}])

      conn =
        post(conn, Routes.grant_request_group_path(conn, :create), grant_request_group: attrs)

      assert response(conn, :forbidden)
    end

    @tag authentication: [role: "admin"]
    test "creates grant_request_group with user_name", %{conn: conn, create_attrs: create_attrs} do
      user_name_params =
        create_attrs
        |> Map.delete(:user_id)
        |> Map.put(:user_name, @cache_user_name)

      conn =
        post(conn, Routes.grant_request_group_path(conn, :create),
          grant_request_group: user_name_params
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.grant_request_group_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "request_date" => "2010-04-17T14:00:00.000000Z",
               "user_id" => @cache_user_id
             } = json_response(conn, 200)["data"]
    end

    @tag authentication: [role: "admin"]
    test "on create with missing user_id defaults to connection user", %{
      conn: conn,
      claims: %{user_id: user_id},
      create_attrs: create_attrs
    } do
      missing_user_id_params = Map.delete(create_attrs, :user_id)

      conn =
        post(conn, Routes.grant_request_group_path(conn, :create),
          grant_request_group: missing_user_id_params
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.grant_request_group_path(conn, :show, id))
      assert %{"user_id" => ^user_id} = json_response(conn, 200)["data"]
    end

    @tag authentication: [role: "admin"]
    test "adds defaults values when missing request_date params", %{
      conn: conn,
      create_attrs: create_attrs
    } do
      missing_request_date_params = Map.delete(create_attrs, :request_date)

      conn =
        post(conn, Routes.grant_request_group_path(conn, :create),
          grant_request_group: missing_request_date_params
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.grant_request_group_path(conn, :show, id))
      refute match?(%{"request_date" => nil}, json_response(conn, 200)["data"])
    end

    @tag authentication: [role: "admin"]
    test "fails to create grant_request_group with invalid requests format", %{conn: conn} do
      params_with_requests = Map.put(@create_attrs, :requests, [])

      conn =
        post(conn, Routes.grant_request_group_path(conn, :create),
          grant_request_group: params_with_requests
        )

      assert %{"message" => "at least one request is required"} =
               json_response(conn, :unprocessable_entity)
    end

    @tag authentication: [role: "admin"]
    test "create grant_request_group with valid child requests", %{
      conn: conn,
      data_structure: %{id: ds_id}
    } do
      metadata = %{
        "list" => "one",
        "string" => "foo"
      }

      params_with_requests =
        @create_attrs
        |> Map.put(:type, @template_name)
        |> Map.put(:requests, [
          %{
            "data_structure_id" => ds_id,
            "metadata" => metadata,
            "filters" => %{"foo" => "bar"}
          }
        ])

      conn =
        post(conn, Routes.grant_request_group_path(conn, :create),
          grant_request_group: params_with_requests
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.grant_request_group_path(conn, :show, id))

      assert %{
               "requests" => [
                 %{
                   "data_structure_id" => ^ds_id,
                   "metadata" => ^metadata,
                   "filters" => %{"foo" => "bar"}
                 }
               ]
             } = json_response(conn, 200)["data"]
    end

    @tag authentication: [role: "admin"]
    test "create grant_request_group with data_structure_external_id requests", %{
      conn: conn,
      data_structure: %{
        id: ds_id,
        external_id: ds_external_id
      }
    } do
      params_with_requests =
        Map.put(@create_attrs, :requests, [
          %{
            "data_structure_external_id" => ds_external_id,
            "filters" => %{"foo" => "bar"}
          }
        ])

      conn =
        post(conn, Routes.grant_request_group_path(conn, :create),
          grant_request_group: params_with_requests
        )

      assert %{"id" => id} = json_response(conn, 201)["data"]

      conn = get(conn, Routes.grant_request_group_path(conn, :show, id))

      assert %{
               "requests" => [
                 %{
                   "data_structure_id" => ^ds_id,
                   "filters" => %{"foo" => "bar"}
                 }
               ]
             } = json_response(conn, 200)["data"]
    end

    @tag authentication: [role: "admin"]
    test "fails to create grant_request_group if child requests are invalid", %{conn: conn} do
      params_with_requests =
        Map.put(@create_attrs, :requests, [
          %{
            "data_structure_id" => 888
          }
        ])

      conn =
        post(conn, Routes.grant_request_group_path(conn, :create),
          grant_request_group: params_with_requests
        )

      assert %{
               "message" => "DataStructure"
             } = json_response(conn, :not_found)

      params_with_requests =
        Map.put(@create_attrs, :requests, [
          %{}
        ])

      conn =
        post(conn, Routes.grant_request_group_path(conn, :create),
          grant_request_group: params_with_requests
        )

      assert %{
               "message" => "DataStructure"
             } = json_response(conn, :not_found)
    end

    @tag authentication: [role: "admin"]
    test "fails to create grant_request_group if child requests has invalid metadata", %{
      conn: conn,
      data_structure: %{id: ds_id}
    } do
      params_with_requests =
        @create_attrs
        |> Map.put(:type, @template_name)
        |> Map.put(:requests, [
          %{
            "data_structure_id" => ds_id,
            "metadata" => %{"invalid" => "metadata"}
          }
        ])

      conn =
        post(conn, Routes.grant_request_group_path(conn, :create),
          grant_request_group: params_with_requests
        )

      assert %{"errors" => %{"requests" => [%{"metadata" => ["invalid content"]}]}} =
               json_response(conn, :unprocessable_entity)
    end

    @tag authentication: [role: "admin"]
    test "renders errors when user_id does not exists", %{conn: conn, create_attrs: create_attrs} do
      invalid_user_params = Map.put(create_attrs, "user_id", 88)

      conn =
        post(conn, Routes.grant_request_group_path(conn, :create),
          grant_request_group: invalid_user_params
        )

      assert json_response(conn, :not_found)["message"] == "User"
    end
  end

  describe "update grant_request_group" do
    setup [:create_grant_request_group]

    @tag authentication: [role: "admin"]
    test "renders grant_request_group when data is valid", %{
      conn: conn,
      grant_request_group: %GrantRequestGroup{id: id, user_id: user_id} = grant_request_group
    } do
      conn =
        put(conn, Routes.grant_request_group_path(conn, :update, grant_request_group),
          grant_request_group: @update_attrs
        )

      assert %{"id" => ^id} = json_response(conn, 200)["data"]

      conn = get(conn, Routes.grant_request_group_path(conn, :show, id))

      assert %{
               "id" => ^id,
               "request_date" => "2011-05-18T15:01:01.000000Z",
               "type" => "some updated type",
               "user_id" => ^user_id
             } = json_response(conn, 200)["data"]
    end

    @tag authentication: [user_name: "non_admin"]
    test "non admin cannot update grant_request_group", %{
      conn: conn,
      grant_request_group: %GrantRequestGroup{} = grant_request_group
    } do
      conn =
        put(conn, Routes.grant_request_group_path(conn, :update, grant_request_group),
          grant_request_group: @update_attrs
        )

      assert response(conn, :forbidden)
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{
      conn: conn,
      grant_request_group: grant_request_group
    } do
      conn =
        put(conn, Routes.grant_request_group_path(conn, :update, grant_request_group),
          grant_request_group: @invalid_attrs
        )

      assert json_response(conn, 422)["errors"] != %{}
    end
  end

  describe "delete grant_request_group" do
    setup [:create_grant_request_group]

    @tag authentication: [role: "admin"]
    test "deletes chosen grant_request_group", %{
      conn: conn,
      grant_request_group: grant_request_group
    } do
      conn = delete(conn, Routes.grant_request_group_path(conn, :delete, grant_request_group))
      assert response(conn, 204)

      assert_error_sent 404, fn ->
        get(conn, Routes.grant_request_group_path(conn, :show, grant_request_group))
      end
    end

    @tag authentication: [user_name: "non_admin"]
    test "non admin cannot delete grant_request_group", %{
      conn: conn,
      grant_request_group: grant_request_group
    } do
      conn = delete(conn, Routes.grant_request_group_path(conn, :delete, grant_request_group))

      assert response(conn, :forbidden)
    end
  end

  defp create_grant_request_group(_) do
    grant_request_group = insert(:grant_request_group)
    %{grant_request_group: grant_request_group}
  end
end
