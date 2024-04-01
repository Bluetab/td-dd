defmodule TdDdWeb.GrantRequestGroupControllerTest do
  use TdDdWeb.ConnCase

  alias TdCore.Search.IndexWorkerMock

  @valid_metadata %{"list" => "one", "string" => "foo"}
  @template_name "grant_request_group_controller_test_template"

  setup do
    CacheHelpers.insert_template(name: @template_name)
    %{id: domain_id} = CacheHelpers.insert_domain()
    %{id: data_structure_id} = data_structure = insert(:data_structure, domain_ids: [domain_id])

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
      data_structure: data_structure,
      create_params: create_params
    ]
  end

  describe "index" do
    @tag authentication: [role: "admin"]
    test "lists all grant_request_groups", %{conn: conn} do
      %{id: id} = insert(:grant_request_group)

      assert %{"data" => data} =
               conn
               |> get(Routes.grant_request_group_path(conn, :index))
               |> json_response(:ok)

      assert [%{"id" => ^id}] = data
    end

    @tag authentication: []
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
    @tag authentication: []
    test "non admin user cannot show grant_request_group from other user", %{conn: conn} do
      %{id: id} = insert(:grant_request_group)

      assert conn
             |> get(Routes.grant_request_group_path(conn, :show, id))
             |> response(:forbidden)
    end

    @tag authentication: []
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
    @tag authentication: [role: "admin"]
    test "renders grant_request_group when data is valid", %{
      conn: conn,
      claims: %{user_id: user_id},
      data_structure: %{id: data_structure_id, domain_ids: domain_ids},
      create_params: create_params
    } do
      %{id: alter_domain_id} = build(:domain)
      %{id: alter_data_structure_id} = insert(:data_structure, domain_ids: [alter_domain_id])

      alter_create_params = %{
        "data_structure_id" => alter_data_structure_id,
        "metadata" => @valid_metadata
      }

      new_requests =
        create_params
        |> Map.get("requests")
        |> Enum.concat([alter_create_params])

      new_create_params =
        create_params
        |> Map.put("requests", new_requests)

      assert %{"data" => data} =
               conn
               |> post(Routes.grant_request_group_path(conn, :create),
                 grant_request_group: new_create_params
               )
               |> json_response(:created)

      assert %{"id" => id} = data

      assert %{"data" => data} =
               conn
               |> get(Routes.grant_request_group_path(conn, :show, id))
               |> json_response(:ok)

      assert %{
               "id" => ^id,
               "user_id" => ^user_id,
               "_embedded" => %{"requests" => [request1 | [request2]]}
             } = data

      assert %{
               "_embedded" => %{
                 "data_structure" => %{
                   "id" => ^data_structure_id
                 }
               },
               "domain_ids" => ^domain_ids
             } = request1

      assert %{
               "_embedded" => %{
                 "data_structure" => %{
                   "id" => ^alter_data_structure_id
                 }
               },
               "domain_ids" => [^alter_domain_id]
             } = request2
    end

    @tag authentication: [role: "admin"]
    test "if user_id is specified, will not take the claims user_id", %{
      conn: conn,
      claims: %{user_id: created_by_id},
      create_params: create_params
    } do
      user_id = :rand.uniform(10)
      params = Map.put(create_params, "user_id", user_id)

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

      assert %{
               "id" => ^id,
               "user_id" => ^user_id,
               "created_by_id" => ^created_by_id
             } = data
    end

    @tag authentication: [permissions: [:create_grant_request]]
    test "user without permission cannot create request_group with different user_id", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{id: ds_id} = insert(:data_structure, domain_ids: [domain_id])
      user_id = :rand.uniform(10)

      params = %{
        "user_id" => user_id,
        "requests" => [%{"data_structure_id" => ds_id}],
        "type" => nil
      }

      assert conn
             |> post(Routes.grant_request_group_path(conn, :create),
               grant_request_group: params
             )
             |> json_response(:forbidden)
    end

    @tag authentication: [
           permissions: [
             :create_grant_request,
             :create_foreign_grant_request,
             :view_data_structure
           ]
         ]
    test "user with permission can create request_group on authorized user_id", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{id: ds_id} = insert(:data_structure, domain_ids: [domain_id])

      role_name = "test_role"
      CacheHelpers.put_permission_on_role("allow_foreign_grant_request", role_name)
      %{id: user_id} = CacheHelpers.insert_user()
      CacheHelpers.insert_acl(domain_id, role_name, [user_id])

      params = %{
        "user_id" => user_id,
        "requests" => [%{"data_structure_id" => ds_id}],
        "type" => nil
      }

      assert conn
             |> post(Routes.grant_request_group_path(conn, :create),
               grant_request_group: params
             )
             |> json_response(:created)
    end

    @tag authentication: [
           user: "non_admin",
           permissions: [
             :create_grant_request_group,
             :view_data_structure,
             :manage_grants,
             :create_grant_request
           ]
         ]
    test "creates grant_request_group for grant removal request", %{
      conn: conn,
      claims: %{user_id: user_id},
      domain: %{id: domain_id}
    } do
      %{id: data_structure_id} = insert(:data_structure, domain_ids: [domain_id])
      %{id: grant_id} = insert(:grant, data_structure_id: data_structure_id)

      params = %{
        "requests" => [
          %{
            "grant_id" => grant_id,
            "filters" => %{},
            "request_type" => "grant_removal"
          }
        ],
        "type" => "grant_template"
      }

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

      assert %{
               "id" => ^id,
               "user_id" => ^user_id,
               "_embedded" => %{
                 "requests" => [
                   %{
                     "domain_ids" => [^domain_id],
                     "filters" => %{},
                     "request_type" => "grant_removal"
                   }
                 ]
               }
             } = data
    end

    @tag authentication: [role: "admin"]
    test "renders grant_request_group when data is valid with modification_grant", %{
      conn: conn,
      claims: %{user_id: user_id},
      create_params: create_params
    } do
      %{id: grant_id} = insert(:grant)
      params_with_grant = Map.put(create_params, "modification_grant_id", grant_id)

      assert %{"data" => data} =
               conn
               |> post(Routes.grant_request_group_path(conn, :create),
                 grant_request_group: params_with_grant
               )
               |> json_response(:created)

      assert %{"id" => id} = data

      assert %{"data" => data} =
               conn
               |> get(Routes.grant_request_group_path(conn, :show, id))
               |> json_response(:ok)

      assert %{
               "id" => ^id,
               "user_id" => ^user_id,
               "_embedded" => %{
                 "modification_grant" => %{"id" => ^grant_id}
               }
             } = data
    end

    @tag authentication: []
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

    @tag authentication: [
           user: "non_admin",
           permissions: [:create_grant_request, :view_data_structure]
         ]
    test "user with permission on structure can create grant_request_group", %{
      conn: conn,
      domain: %{id: domain_id},
      claims: %{user_id: user_id}
    } do
      %{id: ds_id} = insert(:data_structure, domain_ids: [domain_id])

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
    test "adds inserted_at timestamp", %{conn: conn, create_params: params} do
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

      assert %{"_embedded" => embedded} = data

      assert %{
               "requests" => [
                 %{
                   "_embedded" => %{"data_structure" => %{"id" => ^ds_id, "external_id" => _}},
                   "metadata" => @valid_metadata,
                   "filters" => %{"foo" => "bar"}
                 }
               ]
             } = embedded
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

      assert %{"_embedded" => embedded} = data

      assert %{
               "requests" => [
                 %{
                   "_embedded" => %{"data_structure" => %{"id" => ^ds_id, "external_id" => _}},
                   "filters" => %{"foo" => "bar"}
                 }
               ]
             } = embedded
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

      assert %{"requests" => [%{"metadata" => ["list: can't be blank - string: can't be blank"]}]} =
               errors
    end
  end

  describe "delete grant_request_group" do
    setup [:create_grant_request_group]

    @tag authentication: [role: "admin"]
    test "deletes chosen grant_request_group", %{
      conn: conn,
      group: group,
      grant_request_id: grant_request_id
    } do
      IndexWorkerMock.clear()

      assert conn
             |> delete(Routes.grant_request_group_path(conn, :delete, group))
             |> response(:no_content)

      assert [{:delete, :grant_requests, [^grant_request_id]}] = IndexWorkerMock.calls()

      assert_error_sent 404, fn ->
        get(conn, Routes.grant_request_group_path(conn, :show, group))
      end
    end

    @tag authentication: []
    test "non admin cannot delete grant_request_group", %{conn: conn, group: group} do
      assert conn
             |> delete(Routes.grant_request_group_path(conn, :delete, group))
             |> response(:forbidden)
    end
  end

  defp create_grant_request_group(_) do
    %{id: grant_request_id, group: group} =
      insert(:grant_request, group: build(:grant_request_group))

    [group: group, grant_request_id: grant_request_id]
  end
end
