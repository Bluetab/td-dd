defmodule TdDdWeb.GrantRequestGroupControllerTest do
  use TdDdWeb.ConnCase

  alias TdDd.Grants.GrantRequestGroup

  @valid_metadata %{"list" => "one", "string" => "foo"}
  @template_name "grant_request_group_controller_test_template"

  setup %{conn: conn} do
    CacheHelpers.insert_template(name: @template_name)
    %{id: data_structure_id} = data_structure = insert(:data_structure)

    create_params = %{
      "requests" => [
        %{
          "data_structure_id" => data_structure_id,
          "metadata" => @valid_metadata
        }
      ],
      "type" => @template_name
    }

    [
      conn: put_req_header(conn, "accept", "application/json"),
      data_structure: data_structure,
      create_params: create_params
    ]
  end

  describe "index" do
    @tag authentication: [role: "admin"]
    test "lists all grant_request_groups", %{conn: conn} do
      assert %{"data" => []} =
               conn
               |> get(Routes.grant_request_group_path(conn, :index))
               |> json_response(:ok)
    end

    @tag authentication: [user_name: "non_admin"]
    test "non admin user can only list own grant_request_groups", %{
      conn: conn,
      claims: %{user_id: user_id}
    } do
      insert(:grant_request_group)
      %{id: id} = insert(:grant_request_group, user_id: user_id)

      assert %{"data" => data} =
               conn
               |> get(Routes.grant_request_group_path(conn, :index))
               |> json_response(:ok)

      assert [%{"id" => ^id}] = data
    end
  end

  describe "show" do
    @tag authentication: [user_namer: "non_admin"]
    test "non admin user cannot show grant_request_group from other user", %{conn: conn} do
      %{id: id} = insert(:grant_request_group)

      assert conn
             |> get(Routes.grant_request_group_path(conn, :show, id))
             |> response(:forbidden)
    end

    @tag authentication: [user_namer: "non_admin"]
    test "non admin user can show own grant_request_group", %{
      conn: conn,
      claims: %{user_id: user_id}
    } do
      %{id: id} = insert(:grant_request_group, user_id: user_id)

      assert conn
             |> get(Routes.grant_request_group_path(conn, :show, id))
             |> json_response(:ok)
    end
  end

  describe "create grant_request_group" do
    @tag authentication: [role: "admin", user_id: 123]
    test "renders grant_request_group when data is valid", %{
      conn: conn,
      create_params: create_params
    } do
      assert %{"data" => data} =
               conn
               |> post(Routes.grant_request_group_path(conn, :create),
                 grant_request_group: create_params
               )
               |> json_response(:created)

      assert %{"id" => id} = data

      assert %{"data" => data} =
               conn
               |> get(Routes.grant_request_group_path(conn, :show, id))
               |> json_response(:ok)

      assert %{
               "id" => ^id,
               "user_id" => 123
             } = data
    end

    @tag authentication: [user: "non_admin"]
    test "user without permission on structure cannot create grant_request_group", %{
      conn: conn,
      create_params: create_params
    } do
      assert conn
             |> post(Routes.grant_request_group_path(conn, :create),
               grant_request_group: create_params
             )
             |> response(:forbidden)
    end

    @tag authentication: [user: "non_admin", permissions: [:create_grant_request]]
    test "user with permission on structure can create grant_request_group", %{
      conn: conn,
      domain: %{id: domain_id},
      claims: %{user_id: user_id}
    } do
      %{id: ds_id} = insert(:data_structure, domain_id: domain_id)

      params = %{
        "requests" => [%{"data_structure_id" => ds_id}],
        "type" => nil
      }

      assert %{"data" => data} =
               conn
               |> post(Routes.grant_request_group_path(conn, :create), grant_request_group: params)
               |> json_response(:created)

      assert %{"id" => id} = data

      assert %{"data" => data} =
               conn
               |> get(Routes.grant_request_group_path(conn, :show, id))
               |> json_response(:ok)

      assert %{
               "id" => ^id,
               "user_id" => ^user_id
             } = data
    end

    @tag authentication: [role: "admin"]
    test "adds inserted_at timestamp", %{
      conn: conn,
      create_params: params
    } do
      assert %{"data" => data} =
               conn
               |> post(Routes.grant_request_group_path(conn, :create),
                 grant_request_group: params
               )
               |> json_response(:created)

      assert %{"id" => id} = data

      assert %{"data" => data} =
               conn
               |> get(Routes.grant_request_group_path(conn, :show, id))
               |> json_response(:ok)

      assert %{"inserted_at" => inserted_at} = data
      assert is_binary(inserted_at)
    end

    @tag authentication: [role: "admin"]
    test "fails to create grant_request_group with invalid requests format", %{conn: conn} do
      params = %{"requests" => []}

      assert %{"message" => "at least one request is required"} =
               conn
               |> post(Routes.grant_request_group_path(conn, :create), grant_request_group: params)
               |> json_response(:unprocessable_entity)
    end

    @tag authentication: [role: "admin"]
    test "create grant_request_group with valid child requests", %{
      conn: conn,
      data_structure: %{id: ds_id}
    } do
      params = %{
        "type" => @template_name,
        "requests" => [
          %{
            "data_structure_id" => ds_id,
            "metadata" => @valid_metadata,
            "filters" => %{"foo" => "bar"}
          }
        ]
      }

      assert %{"data" => data} =
               conn
               |> post(Routes.grant_request_group_path(conn, :create), grant_request_group: params)
               |> json_response(:created)

      assert %{"id" => id} = data

      assert %{"data" => data} =
               conn
               |> get(Routes.grant_request_group_path(conn, :show, id))
               |> json_response(:ok)

      assert %{
               "requests" => [
                 %{
                   "data_structure_id" => ^ds_id,
                   "metadata" => @valid_metadata,
                   "filters" => %{"foo" => "bar"}
                 }
               ]
             } = data
    end

    @tag authentication: [role: "admin"]
    test "create grant_request_group with data_structure_external_id requests", %{
      conn: conn,
      data_structure: %{
        id: ds_id,
        external_id: ds_external_id
      }
    } do
      params = %{
        "type" => @template_name,
        "requests" => [
          %{
            "data_structure_external_id" => ds_external_id,
            "filters" => %{"foo" => "bar"},
            "metadata" => @valid_metadata
          }
        ]
      }

      assert %{"data" => data} =
               conn
               |> post(Routes.grant_request_group_path(conn, :create), grant_request_group: params)
               |> json_response(:created)

      assert %{"id" => id} = data

      assert %{"data" => data} =
               conn
               |> get(Routes.grant_request_group_path(conn, :show, id))
               |> json_response(:ok)

      assert %{"requests" => [%{"data_structure_id" => ^ds_id, "filters" => %{"foo" => "bar"}}]} =
               data
    end

    @tag authentication: [role: "admin"]
    test "fails to create grant_request_group if child requests are invalid", %{conn: conn} do
      params = %{
        "requests" => [%{"data_structure_id" => 888}],
        "type" => @template_name
      }

      assert %{"message" => "DataStructure"} =
               conn
               |> post(Routes.grant_request_group_path(conn, :create), grant_request_group: params)
               |> json_response(:not_found)

      params = %{
        "requests" => [%{}],
        "type" => @template_name
      }

      assert %{"message" => "DataStructure"} =
               conn
               |> post(Routes.grant_request_group_path(conn, :create), grant_request_group: params)
               |> json_response(:not_found)
    end

    @tag authentication: [role: "admin"]
    test "fails to create grant_request_group if child requests has invalid metadata", %{
      conn: conn,
      data_structure: %{id: ds_id}
    } do
      params = %{
        "type" => @template_name,
        "requests" => [
          %{
            "data_structure_id" => ds_id,
            "metadata" => %{"invalid" => "metadata"}
          }
        ]
      }

      assert %{"errors" => errors} =
               conn
               |> post(Routes.grant_request_group_path(conn, :create), grant_request_group: params)
               |> json_response(:unprocessable_entity)

      assert %{"requests" => [%{"metadata" => ["invalid content"]}]} = errors
    end
  end

  describe "update grant_request_group" do
    setup [:create_grant_request_group]

    @tag authentication: [role: "admin"]
    test "renders grant_request_group when data is valid", %{
      conn: conn,
      grant_request_group: %GrantRequestGroup{id: id, user_id: user_id} = grant_request_group
    } do
      params = %{"type" => "some updated type"}

      assert %{"data" => data} =
               conn
               |> put(Routes.grant_request_group_path(conn, :update, grant_request_group),
                 grant_request_group: params
               )
               |> json_response(:ok)

      assert %{"id" => ^id} = data

      assert %{"data" => data} =
               conn
               |> get(Routes.grant_request_group_path(conn, :show, id))
               |> json_response(:ok)

      assert %{
               "id" => ^id,
               "inserted_at" => _,
               "type" => "some updated type",
               "user_id" => ^user_id
             } = data
    end

    @tag authentication: [user_name: "non_admin"]
    test "non admin cannot update grant_request_group", %{
      conn: conn,
      grant_request_group: %GrantRequestGroup{} = grant_request_group
    } do
      params = %{"type" => "some updated type"}

      assert conn
             |> put(Routes.grant_request_group_path(conn, :update, grant_request_group),
               grant_request_group: params
             )
             |> response(:forbidden)
    end

    @tag authentication: [role: "admin"]
    test "renders errors when data is invalid", %{
      conn: conn,
      grant_request_group: grant_request_group
    } do
      params = %{"requests" => nil}

      assert %{"errors" => errors} =
               conn
               |> put(Routes.grant_request_group_path(conn, :update, grant_request_group),
                 grant_request_group: params
               )
               |> json_response(:unprocessable_entity)

      assert %{} = errors
      refute errors == %{}
    end
  end

  describe "delete grant_request_group" do
    setup [:create_grant_request_group]

    @tag authentication: [role: "admin"]
    test "deletes chosen grant_request_group", %{
      conn: conn,
      grant_request_group: grant_request_group
    } do
      assert conn
             |> delete(Routes.grant_request_group_path(conn, :delete, grant_request_group))
             |> response(:no_content)

      assert_error_sent 404, fn ->
        get(conn, Routes.grant_request_group_path(conn, :show, grant_request_group))
      end
    end

    @tag authentication: [user_name: "non_admin"]
    test "non admin cannot delete grant_request_group", %{
      conn: conn,
      grant_request_group: grant_request_group
    } do
      assert conn
             |> delete(Routes.grant_request_group_path(conn, :delete, grant_request_group))
             |> response(:forbidden)
    end
  end

  defp create_grant_request_group(_) do
    %{grant_request_group: grant_request_group} =
      insert(:grant_request, grant_request_group: build(:grant_request_group))

    [grant_request_group: grant_request_group]
  end
end
