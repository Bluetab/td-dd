defmodule TdDdWeb.DataStructureControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  import Mox
  import Routes

  alias Path
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.StructureNotes

  @moduletag sandbox: :shared
  @template_name "data_structure_controller_test_template"
  @template_with_multifields_name "data_structure_controller_test_template_with_multifields"
  @receive_timeout 500
  @protected DataStructures.protected()

  defp plug_upload(path) do
    %Plug.Upload{
      path: path,
      filename: Path.basename(path)
    }
  end

  # function that returns the function to be injected
  def notify_callback do
    pid = self()

    fn reason, msg ->
      # send msg back to test process
      Kernel.send(pid, {reason, msg})
      :ok
    end
  end

  setup_all do
    start_supervised({Task.Supervisor, name: TdDd.TaskSupervisor})
    start_supervised!(TdDd.Lineage.GraphData)
    start_supervised!(TdDd.Search.Cluster)
    :ok
  end

  setup :verify_on_exit!

  setup context do
    %{id: template_id, name: template_name} = CacheHelpers.insert_template(name: @template_name)

    %{id: template_with_multifields_id, name: template_with_multifields_name} =
      CacheHelpers.insert_template(name: @template_with_multifields_name, cardinality: "+")

    system = insert(:system)

    domain =
      case context do
        %{domain: domain} ->
          domain

        _ ->
          CacheHelpers.insert_domain()
      end

    CacheHelpers.insert_structure_type(name: template_name, template_id: template_id)

    CacheHelpers.insert_structure_type(
      name: template_with_multifields_name,
      template_id: template_with_multifields_id
    )

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
        |> expect(:request, fn _, :post, "/structures/_search", _, _ ->
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
        data_structure_version = insert(:data_structure_version, domain_ids: [domain_id])

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", _, _ ->
        SearchHelpers.hits_response([data_structure_version])
      end)

      assert %{"data" => data} =
               conn
               |> get(data_structure_path(conn, :index))
               |> json_response(:ok)

      assert [%{"id" => ^id, "name" => ^name, "external_id" => ^external_id}] = data
    end

    @tag authentication: [role: "admin"]
    test "response includes alias as name and original name", %{conn: conn} do
      %{name: name} =
        data_structure_version =
        insert(:data_structure_version,
          data_structure: build(:data_structure, alias: "my_alias"),
          type: @template_name
        )

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", _, _ ->
        SearchHelpers.hits_response([data_structure_version])
      end)

      assert %{"data" => data} =
               conn
               |> get(data_structure_path(conn, :index))
               |> json_response(:ok)

      assert [%{"name" => "my_alias", "original_name" => ^name}] = data
    end
  end

  describe "search" do
    setup :create_data_structure

    @tag authentication: [role: "admin"]
    test "search without query includes match_all clause", %{conn: conn} do
      %{data_structure_id: id} = dsv = insert(:data_structure_version)

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", %{query: query}, _ ->
        assert query == %{
                 bool: %{
                   filter: %{match_all: %{}},
                   must_not: %{exists: %{field: "deleted_at"}}
                 }
               }

        SearchHelpers.hits_response([dsv])
      end)

      assert %{"data" => [%{"id" => ^id}]} =
               conn
               |> post(data_structure_path(conn, :search), %{})
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "search with query includes multi_match clause", %{conn: conn} do
      %{data_structure_id: id} = dsv = insert(:data_structure_version)

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", %{query: query}, _ ->
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
      data_structure: %{id: id, domain_ids: [old_domain_id]} = data_structure,
      swagger_schema: schema
    } do
      %{id: new_domain_id} = CacheHelpers.insert_domain()
      attrs = %{domain_ids: [new_domain_id]}

      CacheHelpers.put_session_permissions(claims, %{
        update_data_structure: [old_domain_id],
        manage_confidential_structures: [old_domain_id, new_domain_id],
        manage_structures_domain: [old_domain_id, new_domain_id],
        view_data_structure: [old_domain_id, new_domain_id]
      })

      assert %{"data" => %{"id" => ^id}} =
               conn
               |> put(data_structure_path(conn, :update, data_structure), data_structure: attrs)
               |> validate_resp_schema(schema, "DataStructureResponse")
               |> json_response(:ok)

      assert %{domain_ids: [^new_domain_id]} = DataStructures.get_data_structure!(id)
    end

    @tag authentication: [role: "user"]
    test "needs manage_confidential_structures permission", %{
      conn: conn,
      claims: claims,
      data_structure: %{domain_ids: [domain_id]} = data_structure,
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

    @tag authentication: [
           role: "user",
           permissions: [
             :view_data_structure,
             :update_data_structure,
             :manage_confidential_structures,
             :view_protected_metadata
           ]
         ]
    test "shows updated structure protected metadata if user has view_protected_metadata permission",
         %{
           conn: conn,
           data_structure: data_structure,
           swagger_schema: schema
         } do
      mutable_metadata = %{
        "mm_foo" => "mm_foo",
        @protected => %{"mm_protected" => "mm_protected"}
      }

      insert(:structure_metadata, data_structure_id: data_structure.id, fields: mutable_metadata)

      assert %{"data" => data} =
               conn
               |> put(data_structure_path(conn, :update, data_structure),
                 data_structure: %{confidential: true}
               )
               |> validate_resp_schema(schema, "DataStructureResponse")
               |> json_response(:ok)

      assert %{
               "metadata_versions" => [
                 %{
                   "fields" => ^mutable_metadata
                 }
               ]
             } = data
    end

    @tag authentication: [
           role: "user",
           permissions: [
             :view_data_structure,
             :update_data_structure,
             :manage_confidential_structures
           ]
         ]
    test "filters updated structure protected metadata if user does not have view_protected_metadata permission",
         %{
           conn: conn,
           data_structure: data_structure,
           swagger_schema: schema
         } do
      mutable_metadata = %{
        "mm_foo" => "mm_foo",
        @protected => %{"mm_protected" => "mm_protected"}
      }

      insert(:structure_metadata, data_structure_id: data_structure.id, fields: mutable_metadata)

      assert %{"data" => data} =
               conn
               |> put(data_structure_path(conn, :update, data_structure),
                 data_structure: %{confidential: true}
               )
               |> validate_resp_schema(schema, "DataStructureResponse")
               |> json_response(:ok)

      assert %{
               "metadata_versions" => [
                 %{
                   "fields" => fields
                 }
               ]
             } = data

      assert fields == %{"mm_foo" => "mm_foo"}
    end

    @tag authentication: [role: "user"]
    test "needs manage_structures_domain permission", %{
      conn: conn,
      claims: claims,
      data_structure: %{domain_ids: [domain_id]} = data_structure,
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
      data_structure: %{domain_ids: [domain_id]} = data_structure,
      swagger_schema: schema
    } do
      %{id: new_domain_id} = CacheHelpers.insert_domain()

      CacheHelpers.put_session_permissions(claims, %{
        domain_id => [:update_data_structure, :manage_structures_domain],
        new_domain_id => [:view_data_structure, :manage_confidential_structures]
      })

      assert conn
             |> put(data_structure_path(conn, :update, data_structure),
               data_structure: %{domain_ids: [new_domain_id]}
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
      assert %{"data_structure" => %{"domains" => [%{"name" => ^domain_name}]}} = data
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
    test "bulk update of data structures with no initial matches", %{conn: conn} do
      ElasticsearchMock
      |> expect(
        :request,
        fn _, :post, "/structures/_search", %{query: query, size: 10_000}, opts ->
          assert opts == [params: %{"scroll" => "1m"}]

          assert query == %{
                   bool: %{
                     filter: %{term: %{"type.raw" => "Field"}},
                     must_not: %{exists: %{field: "deleted_at"}}
                   }
                 }

          SearchHelpers.hits_response([])
        end
      )

      assert %{"errors" => [], "ids" => []} =
               conn
               |> post(Routes.data_structure_path(conn, :bulk_update), %{
                 "bulk_update_request" => %{
                   "update_attributes" => %{
                     "df_content" => %{
                       "list" => "one",
                       "string" => "hola soy un string"
                     },
                     "otra_cosa" => 2
                   },
                   "search_params" => %{
                     "filters" => %{"type.raw" => ["Field"]}
                   }
                 }
               })
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "bulk update of data structures uses scroll to search", %{conn: conn} do
      %{data_structure_id: id1} = dsv1 = insert(:data_structure_version, type: @template_name)
      %{data_structure_id: id2} = dsv2 = insert(:data_structure_version, type: @template_name)

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", %{query: query}, opts ->
        assert opts == [params: %{"scroll" => "1m"}]

        assert query == %{
                 bool: %{
                   filter: %{terms: %{"id" => [id1, id2]}},
                   must_not: %{exists: %{field: "deleted_at"}}
                 }
               }

        SearchHelpers.scroll_response([dsv1])
      end)
      |> expect(:request, fn _, :post, "/_search/scroll", body, [] ->
        assert body == %{"scroll" => "1m", "scroll_id" => "some_scroll_id"}
        SearchHelpers.scroll_response([dsv2])
      end)
      |> expect(:request, fn _, :post, "/_search/scroll", body, [] ->
        assert body == %{"scroll" => "1m", "scroll_id" => "some_scroll_id"}
        SearchHelpers.scroll_response([])
      end)

      assert %{"errors" => [], "ids" => [^id1, ^id2]} =
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
                     "filters" => %{"id" => [id1, id2]}
                   }
                 }
               })
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "bulk update return invalid notes as errors", %{conn: conn, domain_id: domain_id} do
      %{id: id, external_id: external_id} = insert(:data_structure, domain_ids: [domain_id])
      dsv = insert(:data_structure_version, data_structure_id: id, type: @template_name)

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", %{query: query}, opts ->
        assert opts == [params: %{"scroll" => "1m"}]

        assert query == %{
                 bool: %{
                   filter: %{term: %{"note_id" => 123}},
                   must_not: %{exists: %{field: "deleted_at"}}
                 }
               }

        SearchHelpers.scroll_response([dsv])
      end)
      |> expect(:request, fn _, :post, "/_search/scroll", body, [] ->
        assert body == %{"scroll" => "1m", "scroll_id" => "some_scroll_id"}
        SearchHelpers.scroll_response([])
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

  describe "upload structure domains csv" do
    @tag authentication: [role: "user"]
    test "prevent upload for non-admin user missing :manage_structures_domain permission",
         %{conn: conn, domain: %{id: domain_id}} do
      create_three_data_structures(domain_id, "bar_external_id")

      conn
      |> post(data_structure_path(conn, :bulk_upload_domains),
        structures_domains: plug_upload("test/fixtures/td4535/structures_domains_good.csv")
      )
      |> json_response(:forbidden)
    end

    @tag authentication: [role: "user"]
    test "succeed on valid csv", %{conn: conn, claims: claims} do
      %{id: bar_domain_id} = CacheHelpers.insert_domain(%{external_id: "bar"})
      %{id: foo_domain_id} = CacheHelpers.insert_domain(%{external_id: "foo"})

      CacheHelpers.put_session_permissions(claims, %{
        manage_structures_domain: [bar_domain_id, foo_domain_id],
        view_data_structure: [bar_domain_id, foo_domain_id]
      })

      {[id_one, _id_two, id_three], [_, bar_external_id_2, _]} =
        create_three_data_structures(bar_domain_id, "bar_external_id")

      data =
        conn
        |> post(data_structure_path(conn, :bulk_upload_domains),
          structures_domains: plug_upload("test/fixtures/td4535/structures_domains_good.csv")
        )
        |> json_response(:ok)

      assert data == %{
               "ids" => [id_one, id_three],
               "errors" => [
                 %{
                   "row" => 4,
                   "message" => %{
                     "domain" => ["not_exist"]
                   },
                   "external_id" => bar_external_id_2
                 },
                 %{
                   "row" => 6,
                   "message" => %{
                     "structure" => ["not_exist"]
                   },
                   "external_id" => "non_existent_id"
                 }
               ]
             }
    end

    @tag authentication: [role: "user", permissions: [:manage_structures_domain]]
    test "change only domains where user have permissions", %{
      conn: conn,
      claims: claims
    } do
      %{id: bar_domain_id} = CacheHelpers.insert_domain(%{external_id: "bar"})
      %{id: foo_domain_id} = CacheHelpers.insert_domain(%{external_id: "foo"})
      %{id: pan_domain_id} = CacheHelpers.insert_domain(%{external_id: "pan"})

      CacheHelpers.put_session_permissions(claims, %{
        manage_structures_domain: [bar_domain_id, foo_domain_id],
        view_data_structure: [bar_domain_id, foo_domain_id]
      })

      {[bar_id_one, _bar_id_two, _bar_id_three],
       [_bar_external_id_1, _bar_external_id_2, _bar_external_id_3]} =
        create_three_data_structures(bar_domain_id, "bar_external_id")

      {[_foo_id_one, foo_id_two, _foo_id_three],
       [_foo_external_id_1, _foo_external_id_2, foo_external_id_3]} =
        create_three_data_structures(foo_domain_id, "foo_external_id")

      {[_pan_id_one, _pan_id_two, _pan_id_three],
       [pan_external_id_1, _pan_external_id_2, _pan_external_id_3]} =
        create_three_data_structures(pan_domain_id, "pan_external_id")

      data =
        conn
        |> post(data_structure_path(conn, :bulk_upload_domains),
          structures_domains:
            plug_upload("test/fixtures/td4535/structures_domains_permissions.csv")
        )
        |> json_response(:ok)

      assert data == %{
               "ids" => [bar_id_one, foo_id_two],
               "errors" => [
                 %{
                   "external_id" => foo_external_id_3,
                   "message" => %{
                     "update_domain" => ["forbidden"]
                   },
                   "row" => 4
                 },
                 %{
                   "external_id" => "baz_external_id_1",
                   "message" => %{
                     "structure" => ["not_exist"]
                   },
                   "row" => 5
                 },
                 %{
                   "external_id" => pan_external_id_1,
                   "message" => %{
                     "update_domain" => ["forbidden"]
                   },
                   "row" => 6
                 }
               ]
             }
    end

    @tag authentication: [role: "user", permissions: [:manage_structures_domain]]
    test "throw error on invalid csv (bad header)", %{conn: conn} do
      data =
        conn
        |> post(data_structure_path(conn, :bulk_upload_domains),
          structures_domains:
            plug_upload("test/fixtures/td4535/structures_domains_bad_header.csv")
        )
        |> json_response(:unprocessable_entity)

      %{
        "error" => %{"message" => message}
      } = data

      assert message =~ ~r/invalid_headers/
    end

    @tag authentication: [
           role: "user",
           permissions: [:manage_structures_domain, :view_data_structure]
         ]
    test "throw error on invalid csv (missing external_id fields)", %{
      conn: conn,
      domain_id: domain_id
    } do
      {[_, _id_two, _id_three], [external_id_1, external_id_2, external_id_3]} =
        create_three_data_structures(domain_id, "some_external_id")

      TdCache.TaxonomyCache.get_domain_ids()

      data =
        conn
        |> post(data_structure_path(conn, :bulk_upload_domains),
          structures_domains:
            plug_upload("test/fixtures/td4535/structures_domains_bad_missing_external_id.csv")
        )
        |> json_response(:ok)

      assert data == %{
               "errors" => [
                 %{
                   "external_id" => external_id_1,
                   "message" => %{
                     "domain_ids" => ["must be a non-empty list"]
                   },
                   "row" => 2
                 },
                 %{
                   "external_id" => external_id_2,
                   "message" => %{
                     "domain" => ["not_exist"]
                   },
                   "row" => 3
                 },
                 %{
                   "external_id" => external_id_3,
                   "message" => %{
                     "domain" => ["not_exist"]
                   },
                   "row" => 4
                 }
               ],
               "ids" => []
             }
    end

    @tag authentication: [role: "user", permissions: [:manage_structures_domain]]

    test "report errors on invalid rows and insert valid ones", %{
      conn: conn,
      claims: claims
    } do
      %{id: foo_domain_id} = CacheHelpers.insert_domain(%{external_id: "foo"})
      %{id: bar_domain_id} = CacheHelpers.insert_domain(%{external_id: "bar"})
      %{id: zoo_domain_id} = CacheHelpers.insert_domain(%{external_id: "zoo"})

      CacheHelpers.put_session_permissions(claims, %{
        manage_structures_domain: [foo_domain_id, zoo_domain_id],
        view_data_structure: [foo_domain_id, zoo_domain_id]
      })

      {[_, _, id_three], [external_id_1, external_id_2, _external_id_3]} =
        create_three_data_structures(foo_domain_id, "some_external_id")

      {_, [bar_external_id_1, _, _]} =
        create_three_data_structures(bar_domain_id, "bar_external_id")

      data =
        conn
        |> post(data_structure_path(conn, :bulk_upload_domains),
          structures_domains:
            plug_upload("test/fixtures/td4535/structures_domains_warning_inexistent.csv")
        )
        |> json_response(:ok)

      assert data == %{
               "ids" => [id_three],
               "errors" => [
                 %{
                   "row" => 2,
                   "message" => %{
                     "domain" => ["not_exist"]
                   },
                   "external_id" => external_id_1
                 },
                 %{
                   "row" => 4,
                   "message" => %{
                     "update_domain" => ["forbidden"]
                   },
                   "external_id" => external_id_2
                 },
                 %{
                   "row" => 5,
                   "message" => %{
                     "update_domain" => ["forbidden"]
                   },
                   "external_id" => bar_external_id_1
                 }
               ]
             }
    end
  end

  describe "csv" do
    setup :create_data_structure

    setup do
      start_supervised!({TdDd.DataStructures.BulkUpdater, notify: notify_callback()})
      :ok
    end

    @tag authentication: [role: "admin"]
    test "gets csv content using scroll to search", %{conn: conn} do
      dsv = insert(:data_structure_version)

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", _, opts ->
        assert opts == [params: %{"scroll" => "1m"}]
        SearchHelpers.scroll_response([dsv])
      end)
      |> expect(:request, fn _, :post, "/_search/scroll", body, [] ->
        assert body == %{"scroll" => "1m", "scroll_id" => "some_scroll_id"}
        SearchHelpers.scroll_response([])
      end)

      assert %{resp_body: resp_body} = post(conn, data_structure_path(conn, :csv, %{}))
      assert [_header, _row, ""] = String.split(resp_body, "\r\n")
    end

    @tag authentication: [
           role: "user",
           permissions: [:manage_structures_domain, :view_data_structure]
         ]
    test "gets csv content using scroll to search, filter by taxonomy", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{id: child_domain_id} = CacheHelpers.insert_domain(parent_id: domain_id)

      %{name: name} =
        dsv =
        insert(:data_structure_version,
          data_structure: build(:data_structure, domain_ids: [child_domain_id])
        )

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", %{query: query}, opts ->
        assert opts == [params: %{"scroll" => "1m"}]

        assert %{
                 bool: %{
                   filter: [
                     # The query taxonomy filter gets converted to the field "domain_ids"
                     %{terms: %{"domain_ids" => [_domain_id, _child_domain_id]}},
                     %{term: %{"confidential" => false}}
                   ],
                   must_not: %{exists: %{field: "deleted_at"}}
                 }
               } = query

        SearchHelpers.scroll_response([dsv])
      end)
      |> expect(:request, fn _, :post, "/_search/scroll", body, opts ->
        assert opts == []
        assert body == %{"scroll" => "1m", "scroll_id" => "some_scroll_id"}
        SearchHelpers.scroll_response([])
      end)

      params = %{"filters" => %{"taxonomy" => [domain_id]}}

      assert [row] =
               post(conn, data_structure_path(conn, :csv), params)
               |> response(:ok)
               |> String.split("\r\n")
               |> Enum.reject(&(&1 == ""))
               |> CSV.decode!(headers: true, separator: ?;)
               |> Enum.to_list()

      assert %{"name" => ^name} = row
    end

    @tag authentication: [role: "admin"]
    test "gets editable csv content using scroll to search", %{
      conn: conn,
      data_structure: data_structure,
      data_structure_version: dsv
    } do
      insert(:structure_note,
        data_structure: data_structure,
        df_content: %{"string" => "foo", "list" => "bar"},
        status: :published
      )

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", _, opts ->
        assert opts == [params: %{"scroll" => "1m"}]
        SearchHelpers.scroll_response([dsv])
      end)
      |> expect(:request, fn _, :post, "/_search/scroll", body, [] ->
        assert body == %{"scroll" => "1m", "scroll_id" => "some_scroll_id"}
        SearchHelpers.scroll_response([])
      end)

      assert %{resp_body: body} = post(conn, data_structure_path(conn, :editable_csv, %{}))

      %{external_id: external_id} = data_structure
      %{name: name, type: type, path: path} = dsv

      assert body == """
             external_id;name;type;path;string;list\r
             #{external_id};#{name};#{type};#{Enum.join(path, "")};foo;bar\r
             """
    end

    @tag authentication: [role: "admin"]
    test "upload, throw error with invalid csv", %{conn: conn, domain: %{id: domain_id}} do
      _ = create_three_data_structures(domain_id, "some_external_id")

      conn
      |> post(data_structure_path(conn, :bulk_update_template_content),
        structures: plug_upload("test/fixtures/td3787/upload_unprocessable_entity.csv")
      )
      |> json_response(:unprocessable_entity)
    end

    @tag authentication: [role: "admin"]
    test "upload, allow load csv with multiple valid rows", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      {ids, _} = create_three_data_structures(domain_id, "some_external_id")

      assert %{
               "csv_hash" => _csv_hash,
               "status" => "JUST_STARTED",
               "task_reference" => _task_reference
             } =
               conn
               |> post(data_structure_path(conn, :bulk_update_template_content),
                 structures: plug_upload("test/fixtures/td4100/upload.csv")
               )
               |> json_response(:accepted)

      assert_receive {:info, {_ref, %{errors: [], ids: ^ids}}}, @receive_timeout

      assert [
               %{
                 "csv_hash" => _csv_hash,
                 "status" => "COMPLETED",
                 "task_reference" => _task_reference,
                 "response" => %{"ids" => ^ids, "errors" => []}
               }
               | _
             ] =
               conn
               |> get(Routes.csv_bulk_update_event_path(conn, :index))
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "upload, allow load csv partially with one invalid row", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      {[id_one, _, id_three], [_, external_id_2, _]} =
        create_three_data_structures(domain_id, "some_external_id")

      assert %{
               "csv_hash" => _csv_hash,
               "status" => "JUST_STARTED",
               "task_reference" => _task_reference
             } =
               conn
               |> post(data_structure_path(conn, :bulk_update_template_content),
                 structures: plug_upload("test/fixtures/td4100/upload_with_one_warning.csv")
               )
               |> json_response(:accepted)

      assert_receive {:info, {_ref, %{errors: _, ids: _}}}, @receive_timeout

      assert [
               %{
                 "csv_hash" => _csv_hash,
                 "status" => "COMPLETED",
                 "task_reference" => _task_reference,
                 "response" => %{
                   "ids" => [^id_one, ^id_three],
                   "errors" => [
                     %{
                       "row" => 3,
                       "message" => "df_content.inclusion",
                       "external_id" => ^external_id_2,
                       "field" => "list"
                     }
                   ]
                 }
               }
               | _
             ] =
               conn
               |> get(Routes.csv_bulk_update_event_path(conn, :index))
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "upload, allow load csv partially with multiple invalid row", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      {[id_one | _], [_, external_id_2, external_id_3]} =
        create_three_data_structures(domain_id, "some_external_id")

      assert %{
               "csv_hash" => _csv_hash,
               "status" => "JUST_STARTED",
               "task_reference" => _task_reference
             } =
               conn
               |> post(data_structure_path(conn, :bulk_update_template_content),
                 structures: plug_upload("test/fixtures/td4100/upload_with_multiple_warnings.csv")
               )
               |> json_response(:accepted)

      assert_receive {:info, {_ref, %{errors: _, ids: _}}}, @receive_timeout

      assert [
               %{
                 "csv_hash" => _csv_hash,
                 "status" => "COMPLETED",
                 "task_reference" => _task_reference,
                 "response" => %{
                   "ids" => [^id_one],
                   "errors" => [
                     %{
                       "row" => 3,
                       "message" => "df_content.inclusion",
                       "external_id" => ^external_id_2,
                       "field" => "list"
                     },
                     %{
                       "row" => 4,
                       "message" => "df_content.inclusion",
                       "external_id" => ^external_id_3,
                       "field" => "list"
                     }
                   ]
                 }
               }
               | _
             ] =
               conn
               |> get(Routes.csv_bulk_update_event_path(conn, :index))
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "upload, allow load csv partially ignoring invalid external_ids", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      {[id_one, _, id_three], _} = create_three_data_structures(domain_id, "some_external_id")

      assert %{
               "csv_hash" => _csv_hash,
               "status" => "JUST_STARTED",
               "task_reference" => _task_reference
             } =
               conn
               |> post(data_structure_path(conn, :bulk_update_template_content),
                 structures:
                   plug_upload("test/fixtures/td4100/upload_with_invalid_external_id.csv")
               )
               |> json_response(:accepted)

      assert_receive {:info, {_ref, %{errors: [], ids: [^id_one, ^id_three]}}}, @receive_timeout

      assert [
               %{
                 "csv_hash" => _csv_hash,
                 "status" => "COMPLETED",
                 "task_reference" => _task_reference,
                 "response" => %{"ids" => [^id_one, ^id_three], "errors" => []}
               }
               | _
             ] =
               conn
               |> get(Routes.csv_bulk_update_event_path(conn, :index))
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "upload, valid csv", %{conn: conn, domain: %{id: domain_id}} do
      data_structure =
        insert(:data_structure,
          domain_ids: [domain_id],
          external_id: "some_external_id_1"
        )

      create_data_structure(data_structure)

      conn
      |> post(data_structure_path(conn, :bulk_update_template_content),
        structures: plug_upload("test/fixtures/td3787/upload.csv")
      )
      |> response(:accepted)

      assert_receive {:info, {_ref, %{errors: _, ids: _}}}, @receive_timeout

      assert [
               %{
                 "csv_hash" => _csv_hash,
                 "filename" => "upload.csv",
                 "status" => "COMPLETED",
                 "task_reference" => _task_reference,
                 "response" => %{"ids" => _, "errors" => []}
               }
               | _
             ] =
               conn
               |> get(Routes.csv_bulk_update_event_path(conn, :index))
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "upload, valid csv with multiple field values", %{conn: conn, domain: %{id: domain_id}} do
      data_structure =
        insert(:data_structure,
          external_id: "some_external_id_1",
          confidential: false,
          domain_ids: [domain_id]
        )

      insert(:data_structure_version,
        data_structure_id: data_structure.id,
        type: @template_with_multifields_name
      )

      conn
      |> post(data_structure_path(conn, :bulk_update_template_content),
        structures: plug_upload("test/fixtures/td4548/upload_with_multifields.csv")
      )
      |> response(:accepted)

      assert_receive {:info, {_ref, %{errors: _, ids: _}}}, @receive_timeout

      assert [
               %{
                 "csv_hash" => _csv_hash,
                 "status" => "COMPLETED",
                 "task_reference" => _task_reference,
                 "response" => %{"ids" => _, "errors" => []}
               }
               | _
             ] =
               conn
               |> get(Routes.csv_bulk_update_event_path(conn, :index))
               |> json_response(:ok)

      %{df_content: %{"string" => multifields}} =
        StructureNotes.get_latest_structure_note(data_structure.id)

      assert ["any", "accepted", "field"] = multifields
    end

    @tag authentication: [user_name: "non_admin_user"]
    test "upload, can not update without permissions", %{conn: conn, domain: %{id: domain_id}} do
      data_structure =
        insert(:data_structure,
          domain_ids: [domain_id],
          external_id: "some_external_id_1"
        )

      create_data_structure(data_structure)

      conn
      |> post(data_structure_path(conn, :bulk_update_template_content),
        structures: plug_upload("test/fixtures/td3787/upload.csv")
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
          domain_ids: [domain_id],
          external_id: "some_external_id_1"
        )

      create_data_structure(data_structure)

      conn
      |> post(data_structure_path(conn, :bulk_update_template_content),
        structures: plug_upload("test/fixtures/td3787/upload.csv")
      )
      |> response(:accepted)

      assert_receive {:info, {_ref, %{errors: _, ids: _}}}, @receive_timeout

      assert [
               %{
                 "csv_hash" => _csv_hash,
                 "status" => "COMPLETED",
                 "task_reference" => _task_reference,
                 "response" => %{"ids" => _, "errors" => []}
               }
               | _
             ] =
               conn
               |> get(Routes.csv_bulk_update_event_path(conn, :index))
               |> json_response(:ok)
    end

    @tag authentication: [
           user_name: "non_admin_user",
           permissions: [
             :edit_structure_note,
             :view_data_structure,
             :create_structure_note
           ]
         ]
    test "upload, can edit structure_notes", %{conn: conn, domain: %{id: domain_id}} do
      data_structure =
        insert(:data_structure,
          domain_ids: [domain_id],
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
        structures: plug_upload("test/fixtures/td3787/upload.csv")
      )
      |> response(:accepted)

      assert_receive {:info, {_ref, %{errors: _, ids: _}}}, @receive_timeout

      assert [
               %{
                 "csv_hash" => _csv_hash,
                 "status" => "COMPLETED",
                 "task_reference" => _task_reference,
                 "response" => %{"ids" => _, "errors" => []}
               }
               | _
             ] =
               conn
               |> get(Routes.csv_bulk_update_event_path(conn, :index))
               |> json_response(:ok)
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
          domain_ids: [domain_id],
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
        structures: plug_upload("test/fixtures/td3787/upload.csv")
      )
      |> response(:accepted)

      assert_receive {:info, {_ref, %{errors: _, ids: _}}}, @receive_timeout

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
          domain_ids: [domain_id],
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
        structures: plug_upload("test/fixtures/td3787/upload.csv"),
        auto_publish: "true"
      )
      |> response(:accepted)

      assert_receive {:info, {_ref, %{errors: _, ids: _}}}, @receive_timeout

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
          domain_ids: [domain_id],
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
        structures: plug_upload("test/fixtures/td3787/upload.csv"),
        auto_publish: "true"
      )
      |> response(:forbidden)
    end
  end

  defp create_data_structure(%{domain: %{id: domain_id}} = tags) do
    data_structure =
      insert(:data_structure,
        confidential: Map.get(tags, :confidential, false),
        domain_ids: [domain_id]
      )

    create_data_structure(data_structure)
  end

  defp create_data_structure(%DataStructure{} = data_structure) do
    data_structure_version =
      insert(:data_structure_version, data_structure_id: data_structure.id, type: @template_name)

    [data_structure: data_structure, data_structure_version: data_structure_version]
  end

  defp create_three_data_structures(domain_id, external_name) do
    [data_structure_one, data_structure_two, data_structure_three] =
      Enum.map(1..3, fn id ->
        insert(:data_structure,
          domain_ids: [domain_id],
          external_id: external_name <> "_#{id}"
        )
      end)

    %{id: id_one, external_id: external_id_one} =
      create_data_structure(data_structure_one)[:data_structure]

    %{id: id_two, external_id: external_id_two} =
      create_data_structure(data_structure_two)[:data_structure]

    %{id: id_three, external_id: external_id_three} =
      create_data_structure(data_structure_three)[:data_structure]

    {[id_one, id_two, id_three], [external_id_one, external_id_two, external_id_three]}
  end
end
