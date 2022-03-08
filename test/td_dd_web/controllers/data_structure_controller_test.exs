defmodule TdDdWeb.DataStructureControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  import Mox
  import Routes

  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.StructureNotes

  @moduletag sandbox: :shared
  @template_name "data_structure_controller_test_template"

  setup_all do
    start_supervised!(TdDd.Lineage.GraphData)
    start_supervised!(TdDd.Search.Cluster)
    :ok
  end

  setup :verify_on_exit!

  setup context do
    %{id: template_id, name: template_name} = CacheHelpers.insert_template(name: @template_name)

    system = insert(:system)

    domain =
      case context do
        %{domain: domain} -> domain
        _ -> CacheHelpers.insert_domain()
      end

    CacheHelpers.insert_structure_type(name: template_name, template_id: template_id)

    start_supervised!(TdDd.Search.StructureEnricher)

    [system: system, domain: domain, domain_id: domain.id]
  end

  describe "index" do
    for role <- ["admin", "service"] do
      @tag authentication: [role: role]
      test "#{role} account can search data structures", %{conn: conn} do
        %{name: name, data_structure: %{id: id, external_id: external_id}} =
          data_structure_version = insert(:data_structure_version)

        ElasticsearchMock
        |> expect(:request, fn _, :post, "/structures/_search", _, [] ->
          SearchHelpers.hits_response([data_structure_version])
        end)

        assert %{"data" => data} =
                 conn
                 |> get(data_structure_path(conn, :index))
                 |> json_response(:ok)

        assert [%{"id" => ^id, "name" => ^name, "external_id" => ^external_id}] = data
      end
    end

    @tag authentication: [role: "user", permissions: ["view_data_structure"]]
    test "user account can search data structures", %{conn: conn, domain_id: domain_id} do
      %{name: name, data_structure: %{id: id, external_id: external_id}} =
        data_structure_version = insert(:data_structure_version, domain_id: domain_id)

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", _, [] ->
        SearchHelpers.hits_response([data_structure_version])
      end)

      assert %{"data" => data} =
               conn
               |> get(data_structure_path(conn, :index))
               |> json_response(:ok)

      assert [%{"id" => ^id, "name" => ^name, "external_id" => ^external_id}] = data
    end
  end

  describe "search" do
    setup :create_data_structure

    @tag authentication: [role: "admin"]
    test "search without query includes match_all clause", %{conn: conn} do
      %{data_structure_id: id} = dsv = insert(:data_structure_version)

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", %{query: query}, [] ->
        assert query == %{
                 bool: %{
                   filter: %{match_all: %{}},
                   must_not: %{exists: %{field: "deleted_at"}}
                 }
               }

        SearchHelpers.hits_response([dsv])
      end)

      assert %{"data" => [%{"id" => ^id}], "filters" => _filters} =
               conn
               |> post(data_structure_path(conn, :search), %{})
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "search with query includes multi_match clause", %{conn: conn} do
      %{data_structure_id: id} = dsv = insert(:data_structure_version)

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", %{query: query}, [] ->
        assert %{bool: %{must: %{multi_match: _}}} = query
        SearchHelpers.hits_response([dsv])
      end)

      assert %{"data" => [%{"id" => ^id}]} =
               conn
               |> post(data_structure_path(conn, :search), %{"query" => "foo"})
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "includes actions for admin role", %{conn: conn} do
      ElasticsearchMock
      |> expect(:request, fn _, _, _, _, _ -> SearchHelpers.hits_response([], 1) end)

      params = %{"filters" => %{"type.raw" => ["foo"]}}

      assert %{"_actions" => actions} =
               conn
               |> post(data_structure_path(conn, :search), params)
               |> json_response(:ok)

      assert %{
               "bulkUpdate" => %{"href" => href, "method" => "POST"},
               "bulkUpload" => _,
               "autoPublish" => _
             } = actions

      assert href == "/api/data_structures/bulk_update"
    end

    @tag authentication: [
           permissions: ["create_structure_note", "publish_structure_note_from_draft"]
         ]
    test "includes actions for a user with permissions", %{conn: conn} do
      ElasticsearchMock
      |> expect(:request, fn _, _, _, _, _ -> SearchHelpers.hits_response([]) end)

      assert %{"_actions" => actions} =
               conn
               |> post(data_structure_path(conn, :search), %{})
               |> json_response(:ok)

      assert %{
               "bulkUpload" => %{"href" => href, "method" => "POST"},
               "autoPublish" => %{"href" => href, "method" => "POST"}
             } = actions

      refute Map.has_key?(actions, "bulkUpdate")
      assert href == "/api/data_structures/bulk_update_template_content"
    end

    @tag authentication: [role: "user", permissions: ["view_data_structure"]]
    test "does not include actions for a user without permissions", %{conn: conn} do
      ElasticsearchMock
      |> expect(:request, fn _, _, _, _, _ -> SearchHelpers.hits_response([]) end)

      assert %{} =
               response =
               conn
               |> post(data_structure_path(conn, :search), %{})
               |> json_response(:ok)

      refute Map.has_key?(response, "_actions")
    end
  end

  describe "search with scroll" do
    @tag authentication: [role: "admin"]
    test "includes scroll_id in response", %{conn: conn} do
      dsvs = Enum.map(1..5, fn _ -> insert(:data_structure_version) end)

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", _, [params: %{"scroll" => "1m"}] ->
        SearchHelpers.scroll_response(dsvs, 7)
      end)

      assert %{"data" => data, "scroll_id" => _scroll_id} =
               conn
               |> post(data_structure_path(conn, :search), %{
                 "filters" => %{"all" => true},
                 "size" => 5,
                 "scroll" => "1m"
               })
               |> json_response(:ok)

      assert length(data) == 5
    end
  end

  describe "update data_structure" do
    setup :create_data_structure

    @tag authentication: [role: "user"]
    test "renders data_structure when data is valid", %{
      conn: conn,
      claims: claims,
      data_structure: %{id: id, domain_id: old_domain_id} = data_structure,
      swagger_schema: schema
    } do
      %{id: new_domain_id} = CacheHelpers.insert_domain()
      attrs = %{domain_id: new_domain_id, confidential: true}

      CacheHelpers.put_session_permissions(claims, %{
        update_data_structure: [old_domain_id],
        manage_confidential_structures: [old_domain_id, new_domain_id],
        manage_structures_domain: [old_domain_id, new_domain_id],
        view_data_structure: [new_domain_id]
      })

      assert %{"data" => %{"id" => ^id}} =
               conn
               |> put(data_structure_path(conn, :update, data_structure), data_structure: attrs)
               |> validate_resp_schema(schema, "DataStructureResponse")
               |> json_response(:ok)

      assert %{domain_id: ^new_domain_id, confidential: true} =
               DataStructures.get_data_structure!(id)
    end

    @tag authentication: [role: "user"]
    test "needs manage_confidential_structures permission", %{
      conn: conn,
      claims: claims,
      data_structure: %{domain_id: domain_id} = data_structure,
      swagger_schema: schema
    } do
      CacheHelpers.put_session_permissions(claims, domain_id, [
        :view_data_structure,
        :update_data_structure
      ])

      assert conn
             |> put(data_structure_path(conn, :update, data_structure),
               data_structure: %{confidential: true}
             )
             |> validate_resp_schema(schema, "DataStructureResponse")
             |> json_response(:forbidden)
    end

    @tag authentication: [role: "user"]
    test "needs manage_structures_domain permission", %{
      conn: conn,
      claims: claims,
      data_structure: %{domain_id: domain_id} = data_structure,
      swagger_schema: schema
    } do
      %{id: new_domain_id} = CacheHelpers.insert_domain()

      CacheHelpers.put_session_permissions(claims, %{
        domain_id => [:update_data_structure],
        new_domain_id => [
          :view_data_structure,
          :manage_structures_domain,
          :manage_confidential_structures
        ]
      })

      assert conn
             |> put(data_structure_path(conn, :update, data_structure),
               data_structure: %{domain_id: new_domain_id}
             )
             |> validate_resp_schema(schema, "DataStructureResponse")
             |> json_response(:forbidden)
    end

    @tag authentication: [role: "user"]
    test "needs access to new domain", %{
      conn: conn,
      claims: claims,
      data_structure: %{domain_id: domain_id} = data_structure,
      swagger_schema: schema
    } do
      %{id: new_domain_id} = CacheHelpers.insert_domain()

      CacheHelpers.put_session_permissions(claims, %{
        domain_id => [:update_data_structure, :manage_structures_domain],
        new_domain_id => [:view_data_structure, :manage_confidential_structures]
      })

      assert conn
             |> put(data_structure_path(conn, :update, data_structure),
               data_structure: %{domain_id: new_domain_id}
             )
             |> validate_resp_schema(schema, "DataStructureResponse")
             |> json_response(:forbidden)
    end
  end

  describe "delete data_structure" do
    setup :create_data_structure

    @tag authentication: [role: "admin"]
    test "deletes chosen data_structure", %{
      conn: conn,
      data_structure: data_structure,
      swagger_schema: schema
    } do
      assert conn
             |> delete(data_structure_path(conn, :delete, data_structure))
             |> response(:no_content)

      assert_error_sent(404, fn ->
        conn
        |> get(
          data_structure_data_structure_version_path(conn, :show, data_structure.id, "latest")
        )
        |> validate_resp_schema(schema, "DataStructureResponse")
      end)
    end

    @tag authentication: [role: "user"]
    test "user without permission can not delete logical data structure", %{
      conn: conn,
      data_structure: %{id: id}
    } do
      assert(
        %{"errors" => error} =
          conn
          |> delete(data_structure_path(conn, :delete, id, %{"logical" => true}))
          |> json_response(:forbidden)
      )

      assert(%{"detail" => "Invalid authorization"} = error)
    end

    @tag authentication: [role: "admin"]
    test "admin can delete logical data structure", %{
      conn: conn,
      data_structure: %{id: id}
    } do
      assert(
        conn
        |> delete(data_structure_path(conn, :delete, id, %{"logical" => true}))
        |> response(:no_content)
      )

      assert %{"data" => %{"deleted_at" => deleted_at}} =
               conn
               |> get(data_structure_data_structure_version_path(conn, :show, id, "latest"))
               |> json_response(:ok)

      refute is_nil(deleted_at)
    end
  end

  describe "data_structure confidentiality" do
    setup :create_data_structure

    @tag authentication: [role: "admin"]
    test "updates data_structure confidentiality", %{
      conn: conn,
      data_structure: %{id: id} = data_structure
    } do
      assert Map.get(data_structure, :confidential) == false

      assert %{"data" => %{"id" => ^id}} =
               conn
               |> put(data_structure_path(conn, :update, data_structure),
                 data_structure: %{confidential: true}
               )
               |> json_response(:ok)

      assert %{"data" => data} =
               conn
               |> get(data_structure_data_structure_version_path(conn, :show, id, "latest"))
               |> json_response(:ok)

      assert data["data_structure"]["id"] == id
      assert data["data_structure"]["confidential"] == true
    end

    @tag authentication: [
           user_name: "non_admin_user",
           permissions: [
             :view_data_structure,
             :update_data_structure,
             :manage_confidential_structures
           ]
         ]
    @tag :confidential
    test "user with permission can update confidential data_structure", %{
      conn: conn,
      domain: %{name: domain_name},
      data_structure: %{id: id, confidential: true}
    } do
      assert %{"data" => %{"id" => ^id}} =
               conn
               |> put(data_structure_path(conn, :update, id),
                 data_structure: %{confidential: false}
               )
               |> json_response(:ok)

      assert %{"data" => data} =
               conn
               |> get(data_structure_data_structure_version_path(conn, :show, id, "latest"))
               |> json_response(:ok)

      assert data["data_structure"]["id"] == id
      assert data["data_structure"]["confidential"] == false
      assert data["data_structure"]["domain"]["name"] == domain_name
    end

    @tag authentication: [
           user_name: "user_without_permission",
           permissions: [:view_data_structure, :update_data_structure]
         ]
    @tag :confidential
    test "user without confidential permission cannot update confidential data_structure", %{
      conn: conn,
      data_structure: %{id: data_structure_id, confidential: true}
    } do
      assert conn
             |> put(data_structure_path(conn, :update, data_structure_id),
               data_structure: %{confidential: false}
             )
             |> json_response(:forbidden)
    end

    @tag authentication: [
           user_name: "user_without_confidential",
           permissions: [:view_data_structure, :update_data_structure]
         ]
    test "user without confidential permission cannot update confidentiality of data_structure",
         %{
           conn: conn,
           data_structure: %{id: data_structure_id}
         } do
      assert conn
             |> put(data_structure_path(conn, :update, data_structure_id),
               data_structure: %{confidential: true}
             )
             |> json_response(:forbidden)
    end
  end

  describe "bulk_update" do
    @tag authentication: [role: "admin"]
    test "bulk update of data structures", %{conn: conn, domain_id: domain_id} do
      %{data_structure_id: id} =
        dsv = insert(:data_structure_version, domain_id: domain_id, type: @template_name)

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", _, [] ->
        SearchHelpers.hits_response([dsv])
      end)

      assert data =
               conn
               |> post(Routes.data_structure_path(conn, :bulk_update), %{
                 "bulk_update_request" => %{
                   "update_attributes" => %{
                     "df_content" => %{
                       "list" => "one",
                       "string" => "hola soy un string"
                     }
                   },
                   "search_params" => %{
                     "filters" => %{
                       "id" => [id]
                     }
                   }
                 }
               })
               |> json_response(:ok)

      assert %{"errors" => [], "ids" => [^id]} = data
    end

    @tag authentication: [role: "admin"]
    test "bulk update return invalid notes as errors", %{conn: conn, domain_id: domain_id} do
      %{id: id, external_id: external_id} = insert(:data_structure, domain_id: domain_id)
      dsv = insert(:data_structure_version, data_structure_id: id, type: @template_name)

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", %{query: query}, [] ->
        assert query == %{
                 bool: %{
                   filter: %{term: %{"note_id" => 123}},
                   must_not: %{exists: %{field: "deleted_at"}}
                 }
               }

        SearchHelpers.hits_response([dsv])
      end)

      assert %{"errors" => errors, "ids" => []} =
               conn
               |> post(Routes.data_structure_path(conn, :bulk_update), %{
                 "bulk_update_request" => %{
                   "update_attributes" => %{
                     "df_content" => %{
                       "list" => "ones",
                       "string" => "hola soy un string"
                     }
                   },
                   "search_params" => %{
                     "filters" => %{
                       "note_id" => [123]
                     }
                   }
                 }
               })
               |> json_response(:ok)

      assert [
               %{
                 "external_id" => ^external_id,
                 "message" => "df_content.inclusion",
                 "field" => "list"
               }
             ] = errors
    end
  end

  describe "csv" do
    setup :create_data_structure

    @tag authentication: [role: "admin"]
    test "gets csv content", %{conn: conn} do
      dsv = insert(:data_structure_version)

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", %{size: 10_000}, [] ->
        SearchHelpers.hits_response([dsv])
      end)

      assert %{resp_body: resp_body} = post(conn, data_structure_path(conn, :csv, %{}))
      assert [_header, _row, ""] = String.split(resp_body, "\r\n")
    end

    @tag authentication: [role: "admin"]
    test "gets editable csv content", %{
      conn: conn,
      data_structure: data_structure,
      data_structure_version: data_structure_version
    } do
      insert(:structure_note,
        data_structure: data_structure,
        df_content: %{"string" => "foo", "list" => "bar"},
        status: :published
      )

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", _, [] ->
        SearchHelpers.hits_response([data_structure_version])
      end)

      assert %{resp_body: body} = post(conn, data_structure_path(conn, :editable_csv, %{}))

      %{external_id: external_id} = data_structure
      %{name: name, type: type, path: path} = data_structure_version

      assert body == """
             external_id;name;type;path;string;list\r
             #{external_id};#{name};#{type};#{Enum.join(path, "")};foo;bar\r
             """
    end

    @tag authentication: [role: "admin"]
    test "upload, throw error with invalid csv", %{conn: conn} do
      conn
      |> post(data_structure_path(conn, :bulk_update_template_content),
        structures: %Plug.Upload{path: "test/fixtures/td3787/upload.csv"}
      )
      |> json_response(:unprocessable_entity)
    end

    defp create_three_data_structures(domain_id) do
      data_structure_one =
        insert(:data_structure,
          domain_id: domain_id,
          external_id: "some_external_id_1"
        )

      data_structure_two =
        insert(:data_structure,
          domain_id: domain_id,
          external_id: "some_external_id_2"
        )

      data_structure_three =
        insert(:data_structure,
          domain_id: domain_id,
          external_id: "some_external_id_3"
        )

      %{id: id_one, external_id: external_id_one} =
        create_data_structure(data_structure_one)[:data_structure]

      %{id: id_two, external_id: external_id_two} =
        create_data_structure(data_structure_two)[:data_structure]

      %{id: id_three, external_id: external_id_three} =
        create_data_structure(data_structure_three)[:data_structure]

      {[id_one, id_two, id_three], [external_id_one, external_id_two, external_id_three]}
    end

    @tag authentication: [role: "admin"]
    test "upload, allow load csv with multiple valid rows", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      {ids, _} = create_three_data_structures(domain_id)

      data =
        conn
        |> post(data_structure_path(conn, :bulk_update_template_content),
          structures: %Plug.Upload{path: "test/fixtures/td4100/upload.csv"}
        )
        |> json_response(:ok)

      assert data == %{"ids" => ids, "errors" => []}
    end

    @tag authentication: [role: "admin"]
    test "upload, allow load csv partially with one invalid row", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      {[id_one, _, id_three], [_, external_id_2, _]} = create_three_data_structures(domain_id)

      data =
        conn
        |> post(data_structure_path(conn, :bulk_update_template_content),
          structures: %Plug.Upload{path: "test/fixtures/td4100/upload_with_one_warning.csv"}
        )
        |> json_response(:ok)

      assert data == %{
               "ids" => [id_one, id_three],
               "errors" => [
                 %{
                   "row" => 3,
                   "message" => "df_content.inclusion",
                   "external_id" => external_id_2,
                   "field" => "list"
                 }
               ]
             }
    end

    @tag authentication: [role: "admin"]
    test "upload, allow load csv partially with multiple invalid row", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      {[id_one | _], [_, external_id_2, external_id_3]} = create_three_data_structures(domain_id)

      data =
        conn
        |> post(data_structure_path(conn, :bulk_update_template_content),
          structures: %Plug.Upload{path: "test/fixtures/td4100/upload_with_multiple_warnings.csv"}
        )
        |> json_response(:ok)

      assert data == %{
               "ids" => [id_one],
               "errors" => [
                 %{
                   "row" => 3,
                   "message" => "df_content.inclusion",
                   "external_id" => external_id_2,
                   "field" => "list"
                 },
                 %{
                   "row" => 4,
                   "message" => "df_content.inclusion",
                   "external_id" => external_id_3,
                   "field" => "list"
                 }
               ]
             }
    end

    @tag authentication: [role: "admin"]
    test "upload, allow load csv partially ignoring invalid external_ids", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      {[id_one, _, id_three], _} = create_three_data_structures(domain_id)

      data =
        conn
        |> post(data_structure_path(conn, :bulk_update_template_content),
          structures: %Plug.Upload{
            path: "test/fixtures/td4100/upload_with_invalid_external_id.csv"
          }
        )
        |> json_response(:ok)

      assert data == %{
               "ids" => [id_one, id_three],
               "errors" => []
             }
    end

    @tag authentication: [role: "admin"]
    test "upload, valid csv", %{conn: conn, domain: %{id: domain_id}} do
      data_structure =
        insert(:data_structure,
          domain_id: domain_id,
          external_id: "some_external_id_1"
        )

      create_data_structure(data_structure)

      conn
      |> post(data_structure_path(conn, :bulk_update_template_content),
        structures: %Plug.Upload{path: "test/fixtures/td3787/upload.csv"}
      )
      |> response(:ok)
    end

    @tag authentication: [user_name: "non_admin_user"]
    test "upload, can not update without permissions", %{conn: conn, domain: %{id: domain_id}} do
      data_structure =
        insert(:data_structure,
          domain_id: domain_id,
          external_id: "some_external_id_1"
        )

      create_data_structure(data_structure)

      conn
      |> post(data_structure_path(conn, :bulk_update_template_content),
        structures: %Plug.Upload{path: "test/fixtures/td3787/upload.csv"}
      )
      |> response(:forbidden)
    end

    @tag authentication: [
           user_name: "non_admin_user",
           permissions: [
             :create_structure_note,
             :view_data_structure
           ]
         ]
    test "upload, can create structure_notes", %{conn: conn, domain: %{id: domain_id}} do
      data_structure =
        insert(:data_structure,
          domain_id: domain_id,
          external_id: "some_external_id_1"
        )

      create_data_structure(data_structure)

      conn
      |> post(data_structure_path(conn, :bulk_update_template_content),
        structures: %Plug.Upload{path: "test/fixtures/td3787/upload.csv"}
      )
      |> response(:ok)
    end

    @tag authentication: [
           user_name: "non_admin_user",
           permissions: [
             :edit_structure_note,
             :view_data_structure
           ]
         ]
    test "upload, can edit structure_notes", %{conn: conn, domain: %{id: domain_id}} do
      data_structure =
        insert(:data_structure,
          domain_id: domain_id,
          external_id: "some_external_id_1"
        )

      create_data_structure(data_structure)

      insert(:structure_note,
        data_structure: data_structure,
        df_content: %{"string" => "xyzzy", "list" => "two"},
        status: :draft
      )

      conn
      |> post(data_structure_path(conn, :bulk_update_template_content),
        structures: %Plug.Upload{path: "test/fixtures/td3787/upload.csv"}
      )
      |> response(:ok)
    end

    @tag authentication: [
           user_name: "non_admin_user",
           permissions: [
             :create_structure_note,
             :view_data_structure
           ]
         ]
    test "upload, can create structure_notes with a previous published note", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      data_structure =
        insert(:data_structure,
          domain_id: domain_id,
          external_id: "some_external_id_1"
        )

      create_data_structure(data_structure)

      insert(:structure_note,
        data_structure: data_structure,
        df_content: %{"string" => "xyzzy", "list" => "two"},
        status: :published
      )

      conn
      |> post(data_structure_path(conn, :bulk_update_template_content),
        structures: %Plug.Upload{path: "test/fixtures/td3787/upload.csv"}
      )
      |> response(:ok)

      latest_note = StructureNotes.get_latest_structure_note(data_structure.id)
      assert latest_note.status == :draft
      assert latest_note.df_content == %{"string" => "the new content from csv", "list" => "one"}
    end

    @tag authentication: [
           user_name: "non_admin_user",
           permissions: [
             :create_structure_note,
             :view_data_structure,
             :publish_structure_note_from_draft
           ]
         ]
    test "upload, can create and auto-publish structure_notes", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      data_structure =
        insert(:data_structure,
          domain_id: domain_id,
          external_id: "some_external_id_1"
        )

      create_data_structure(data_structure)

      insert(:structure_note,
        data_structure: data_structure,
        df_content: %{"string" => "xyzzy", "list" => "two"},
        status: :published
      )

      conn
      |> post(data_structure_path(conn, :bulk_update_template_content),
        structures: %Plug.Upload{path: "test/fixtures/td3787/upload.csv"},
        auto_publish: "true"
      )
      |> response(:ok)

      latest_note = StructureNotes.get_latest_structure_note(data_structure.id)
      assert latest_note.status == :published
      assert latest_note.df_content == %{"string" => "the new content from csv", "list" => "one"}

      assert data_structure.id
             |> StructureNotes.list_structure_notes(:versioned)
             |> Enum.count() == 1
    end

    @tag authentication: [
           user_name: "non_admin_user",
           permissions: [
             :create_structure_note,
             :view_data_structure
           ]
         ]
    test "upload, can not create and auto-publish structure_notes without draft_to_publish permission",
         %{conn: conn, domain: %{id: domain_id}} do
      data_structure =
        insert(:data_structure,
          domain_id: domain_id,
          external_id: "some_external_id_1"
        )

      create_data_structure(data_structure)

      insert(:structure_note,
        data_structure: data_structure,
        df_content: %{"string" => "xyzzy", "list" => "two"},
        status: :published
      )

      conn
      |> post(data_structure_path(conn, :bulk_update_template_content),
        structures: %Plug.Upload{path: "test/fixtures/td3787/upload.csv"},
        auto_publish: "true"
      )
      |> response(:forbidden)
    end
  end

  defp create_data_structure(%{domain: %{id: domain_id}} = tags) do
    data_structure =
      insert(:data_structure,
        confidential: Map.get(tags, :confidential, false),
        domain_id: domain_id
      )

    create_data_structure(data_structure)
  end

  defp create_data_structure(%DataStructure{} = data_structure) do
    data_structure_version =
      insert(:data_structure_version, data_structure_id: data_structure.id, type: @template_name)

    [data_structure: data_structure, data_structure_version: data_structure_version]
  end
end
