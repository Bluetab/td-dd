defmodule TdDdWeb.DataStructureVersionControllerTest do
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  alias TdCache.TaxonomyCache
  alias TdCache.TemplateCache
  alias TdDd.DataStructures.RelationTypes
  alias TdDd.Lineage.GraphData

  @moduletag sandbox: :shared

  setup_all do
    start_supervised(GraphData)
    :ok
  end

  setup %{conn: conn} do
    start_supervised!(TdDd.Search.StructureEnricher)
    insert(:system, id: 1)
    {:ok, conn: put_req_header(conn, "accept", "application/json")}

    type = "Table"
    template_id = "999"

    {:ok, _} =
      TemplateCache.put(%{
        name: type,
        content: [
          %{
            "name" => "group",
            "fields" => [
              %{
                "name" => "Field1",
                "type" => "string",
                "group" => "Multiple Group",
                "label" => "Multiple 1",
                "values" => nil,
                "cardinality" => "1"
              },
              %{
                "name" => "Field2",
                "type" => "string",
                "group" => "Multiple Group",
                "label" => "Multiple 1",
                "values" => nil,
                "cardinality" => "1"
              }
            ]
          }
        ],
        scope: "test",
        label: "template_label",
        id: template_id,
        updated_at: DateTime.utc_now()
      })

    CacheHelpers.insert_structure_type(template_id: template_id, name: type)

    on_exit(fn -> TemplateCache.delete(template_id) end)
  end

  describe "GET /api/data_structures/:id/versions/:version structure hierarchy" do
    setup :create_structure_hierarchy

    @tag authentication: [role: "admin"]
    test "renders a data structure with children", %{conn: conn, structure: %{id: id}} do
      assert %{"data" => %{"children" => children}} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(conn, :show, id, "latest")
               )
               |> json_response(:ok)

      assert Enum.count(children) == 2
      assert Enum.all?(children, &(Map.get(&1, "order") == 1))
    end

    @tag authentication: [role: "admin"]
    test "renders a data structure with parents", %{conn: conn, structure: %{id: id}} do
      assert %{"data" => %{"parents" => parents}} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(conn, :show, id, "latest")
               )
               |> json_response(:ok)

      assert Enum.count(parents) == 1
    end

    @tag authentication: [role: "admin"]
    test "renders a data structure with siblings", %{
      conn: conn,
      child_structures: [%{id: id} | _]
    } do
      assert %{"data" => %{"siblings" => siblings}} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(conn, :show, id, "latest")
               )
               |> json_response(:ok)

      assert Enum.count(siblings) == 2
    end

    @tag authentication: [role: "admin"]
    test "renders a data structure with metadata", %{
      conn: conn,
      structure: %{id: id}
    } do
      assert %{"data" => %{"metadata" => metadata}} =
               conn
               |> get(Routes.data_structure_data_structure_version_path(conn, :show, id, 0))
               |> json_response(:ok)

      assert %{"foo" => "bar"} = metadata
    end

    @tag authentication: [role: "admin"]
    test "renders metadata versions when exist", %{
      conn: conn,
      parent_structure: %{id: parent_id},
      structure: %{id: child_id}
    } do
      assert %{"data" => %{"metadata_versions" => []}} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(
                   conn,
                   :show,
                   parent_id,
                   "latest"
                 )
               )
               |> json_response(:ok)

      assert %{"data" => %{"metadata_versions" => [_v1]}} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(
                   conn,
                   :show,
                   child_id,
                   "latest"
                 )
               )
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "renders a data structure with source", %{conn: conn, structure: %{id: id}} do
      assert %{"data" => %{"source" => source}} =
               conn
               |> get(Routes.data_structure_data_structure_version_path(conn, :show, id, 0))
               |> json_response(:ok)

      assert %{"external_id" => _, "id" => _} = source
    end

    @tag authentication: [role: "admin"]
    test "renders a data structure by data_structure_version_id", %{
      conn: conn,
      structure_version: %{id: id}
    } do
      assert %{"data" => data} =
               conn
               |> get(Routes.data_structure_version_path(conn, :show, id))
               |> json_response(:ok)

      assert %{"id" => ^id} = data
    end

    @tag authentication: [role: "service"]
    test "service account can view data structure", %{conn: conn, structure: %{id: id}} do
      assert %{"data" => data} =
               conn
               |> get(Routes.data_structure_data_structure_version_path(conn, :show, id, 0))
               |> json_response(:ok)

      assert %{"data_structure" => %{"id" => ^id}} = data
    end
  end

  describe "GET /api/data_structures/:id/versions/:version grants" do
    setup :create_structure_hierarchy

    @tag authentication: [role: "admin"]
    test "renders a data structure with related user grant", %{
      conn: conn,
      structure: %{id: data_structure_id, external_id: data_structure_external_id} = structure,
      structure_version: %{name: data_structure_name},
      claims: %{user_id: user_id}
    } do
      start_date = DateTime.utc_now() |> DateTime.add(-60 * 60 * 24, :second)
      end_date = DateTime.utc_now() |> DateTime.add(60 * 60 * 24, :second)

      %{id: id, detail: detail} =
        insert(:grant,
          data_structure: structure,
          user_id: user_id,
          start_date: start_date,
          end_date: end_date
        )

      assert %{"data" => %{"grant" => grant}} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(
                   conn,
                   :show,
                   structure.id,
                   "latest"
                 )
               )
               |> json_response(:ok)

      start_date_string = DateTime.to_iso8601(start_date)
      end_date_string = DateTime.to_iso8601(end_date)

      assert %{
               "id" => ^id,
               "end_date" => ^end_date_string,
               "start_date" => ^start_date_string,
               "detail" => ^detail,
               "user_id" => ^user_id,
               "data_structure" => %{
                 "id" => ^data_structure_id,
                 "external_id" => ^data_structure_external_id,
                 "name" => ^data_structure_name
               }
             } = grant
    end

    @tag authentication: [role: "admin"]
    test "renders a data structure with grant from parent", %{
      conn: conn,
      structure: structure,
      parent_structure: parent_structure,
      claims: %{user_id: user_id}
    } do
      start_date = DateTime.utc_now() |> DateTime.add(-60 * 60 * 24, :second)
      end_date = DateTime.utc_now() |> DateTime.add(60 * 60 * 24, :second)

      %{id: id, detail: detail} =
        insert(:grant,
          data_structure: parent_structure,
          user_id: user_id,
          start_date: start_date,
          end_date: end_date
        )

      assert %{"data" => %{"grant" => grant}} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(
                   conn,
                   :show,
                   structure.id,
                   "latest"
                 )
               )
               |> json_response(:ok)

      start_date_string = DateTime.to_iso8601(start_date)
      end_date_string = DateTime.to_iso8601(end_date)

      assert %{
               "id" => ^id,
               "end_date" => ^end_date_string,
               "start_date" => ^start_date_string,
               "detail" => ^detail,
               "user_id" => ^user_id
             } = grant
    end

    @tag authentication: [role: "admin"]
    test "renders a data structure without expired grant", %{
      conn: conn,
      structure: structure,
      claims: %{user_id: user_id}
    } do
      start_date = DateTime.utc_now() |> DateTime.add(60 * 60 * 24, :second)
      end_date = DateTime.utc_now() |> DateTime.add(60 * 60 * 24 * 2, :second)

      insert(:grant,
        data_structure: structure,
        user_id: user_id,
        start_date: start_date,
        end_date: end_date
      )

      assert %{"data" => %{"grant" => nil}} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(
                   conn,
                   :show,
                   structure.id,
                   "latest"
                 )
               )
               |> json_response(:ok)
    end

    @tag authentication: [role: "admin"]
    test "renders a data structure grants applying over structure", %{
      conn: conn,
      structure: %{id: data_structure_id, external_id: data_structure_external_id} = structure,
      structure_version: %{name: data_structure_name}
    } do
      start_date = DateTime.utc_now() |> DateTime.add(-60 * 60 * 24, :second)
      end_date = DateTime.utc_now() |> DateTime.add(60 * 60 * 24, :second)

      %{id: id, detail: detail} =
        insert(:grant,
          data_structure: structure,
          start_date: start_date,
          end_date: end_date
        )

      assert %{"data" => %{"grants" => [grant]}} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(
                   conn,
                   :show,
                   structure.id,
                   "latest"
                 )
               )
               |> json_response(:ok)

      start_date_string = DateTime.to_iso8601(start_date)
      end_date_string = DateTime.to_iso8601(end_date)

      assert %{
               "id" => ^id,
               "end_date" => ^end_date_string,
               "start_date" => ^start_date_string,
               "detail" => ^detail,
               "data_structure" => %{
                 "id" => ^data_structure_id,
                 "external_id" => ^data_structure_external_id,
                 "name" => ^data_structure_name
               },
               "data_structure_version" => %{
                 "name" => ^data_structure_name,
                 "ancestry" => [_ | _]
               }
             } = grant
    end

    @tag authentication: [role: "non_admin", permissions: [:view_data_structure]]
    test "renders a data structure without grants when user has not permissions", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      structure = insert(:data_structure, domain_id: domain_id)
      insert(:data_structure_version, data_structure_id: structure.id)

      start_date = DateTime.utc_now() |> DateTime.add(-60 * 60 * 24, :second)
      end_date = DateTime.utc_now() |> DateTime.add(60 * 60 * 24, :second)

      insert(:grant,
        data_structure: structure,
        start_date: start_date,
        end_date: end_date
      )

      assert %{"data" => %{"grants" => nil}} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(
                   conn,
                   :show,
                   structure.id,
                   "latest"
                 )
               )
               |> json_response(:ok)
    end

    @tag authentication: [role: "non_admin", permissions: [:view_data_structure, :view_grants]]
    test "renders a data structure with grants when user has permissions", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      parent = insert(:data_structure, domain_id: domain_id)

      structure =
        %{id: data_structure_id, external_id: data_structure_external_id} =
        insert(:data_structure, domain_id: domain_id)

      parent_version = insert(:data_structure_version, data_structure_id: parent.id)

      structure_version =
        %{name: data_structure_name} =
        insert(:data_structure_version, data_structure_id: data_structure_id)

      relation_type_id = RelationTypes.default_id!()

      insert(:data_structure_relation,
        parent_id: parent_version.id,
        child_id: structure_version.id,
        relation_type_id: relation_type_id
      )

      start_date = DateTime.utc_now() |> DateTime.add(-60 * 60 * 24, :second)
      end_date = DateTime.utc_now() |> DateTime.add(60 * 60 * 24, :second)

      %{id: id, detail: detail} =
        insert(:grant,
          data_structure: structure,
          start_date: start_date,
          end_date: end_date
        )

      assert %{"data" => %{"grants" => [grant]}} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(
                   conn,
                   :show,
                   data_structure_id,
                   "latest"
                 )
               )
               |> json_response(:ok)

      start_date_string = DateTime.to_iso8601(start_date)
      end_date_string = DateTime.to_iso8601(end_date)

      assert %{
               "id" => ^id,
               "end_date" => ^end_date_string,
               "start_date" => ^start_date_string,
               "detail" => ^detail,
               "data_structure" => %{
                 "id" => ^data_structure_id,
                 "external_id" => ^data_structure_external_id,
                 "name" => ^data_structure_name
               },
               "data_structure_version" => %{
                 "name" => ^data_structure_name,
                 "ancestry" => [_ | _]
               }
             } = grant

      assert %{"data" => %{"grants" => []}} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(
                   conn,
                   :show,
                   parent.id,
                   "latest"
                 )
               )
               |> json_response(:ok)
    end
  end

  describe "GET /api/data_structures/:id/versions/latest with classes" do
    @tag authentication: [role: "admin"]
    test "includes classes in the response", %{conn: conn} do
      %{
        data_structure_version: %{data_structure_id: id, version: version},
        name: name,
        class: class
      } = insert(:structure_classification)

      Enum.each(["latest", version], fn v ->
        assert %{"data" => data} =
                 conn
                 |> get(Routes.data_structure_data_structure_version_path(conn, :show, id, v))
                 |> json_response(:ok)

        assert %{"classes" => classes} = data
        assert classes == %{name => class}
      end)
    end

    @tag authentication: [role: "admin"]
    test "includes children classes in the response", %{conn: conn} do
      %{id: parent_version_id, data_structure_id: parent_id, version: version} =
        insert(:data_structure_version)

      %{data_structure_version: %{id: child_version_id}, name: name, class: class} =
        insert(:structure_classification)

      relation_type_id = RelationTypes.default_id!()

      insert(:data_structure_relation,
        parent_id: parent_version_id,
        child_id: child_version_id,
        relation_type_id: relation_type_id
      )

      Enum.each(["latest", version], fn v ->
        assert %{"data" => data} =
                 conn
                 |> get(
                   Routes.data_structure_data_structure_version_path(conn, :show, parent_id, v)
                 )
                 |> json_response(:ok)

        assert %{"children" => [%{"classes" => classes}]} = data
        assert classes == %{name => class}
      end)
    end
  end

  describe "show data_structure with deletions in its hierarchy" do
    setup :create_structure_hierarchy_with_logic_deletions

    @tag authentication: [role: "admin"]
    test "renders a data structure with children including deleted", %{
      conn: conn,
      parent_structure: %{id: parent_id}
    } do
      assert %{"data" => %{"children" => children}} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(
                   conn,
                   :show,
                   parent_id,
                   "latest"
                 )
               )
               |> json_response(:ok)

      assert Enum.count(children) == 3
      assert [deleted_child] = Enum.filter(children, & &1["deleted_at"])
      assert deleted_child["name"] == "Child_deleted"
    end

    @tag authentication: [role: "admin"]
    test "renders a data structure with logic deleted parents", %{
      conn: conn,
      child_structures: [%{id: child_id} | _]
    } do
      assert %{"data" => %{"parents" => [parent]}} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(
                   conn,
                   :show,
                   child_id,
                   "latest"
                 )
               )
               |> json_response(:ok)

      assert parent["name"] != "Parent_deleted"
    end

    @tag authentication: [role: "admin"]
    test "renders a data structure with logic deleted siblings", %{
      conn: conn,
      child_structures: [%{id: id} | _]
    } do
      assert %{"data" => %{"siblings" => siblings}} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(conn, :show, id, "latest")
               )
               |> json_response(:ok)

      assert Enum.count(siblings) == 2
      assert Enum.find(siblings, [], &(Map.get(&1, "name") == "Child_deleted" == []))
    end
  end

  describe "GET /api/data_structures/:id/versions/:version data_field structures" do
    setup :create_data_field_structure

    @tag authentication: [role: "user"]
    test "user whithout permission can not profile structure", %{
      conn: conn,
      claims: %{user_id: user_id},
      data_structure: %{id: id},
      domain: %{id: domain_id}
    } do
      create_acl_entry(user_id, domain_id, [:view_data_structure])

      assert %{"user_permissions" => permissions} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(conn, :show, id, "latest")
               )
               |> json_response(:ok)

      assert %{"profile_permission" => false} = permissions
    end

    @tag authentication: [role: "user"]
    test "user with permission can profile structure", %{
      conn: conn,
      claims: %{user_id: user_id},
      data_structure: %{id: id},
      domain: %{id: domain_id}
    } do
      create_acl_entry(user_id, domain_id, [:view_data_structure, :profile_structures])

      assert %{"user_permissions" => permissions} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(conn, :show, id, "latest")
               )
               |> json_response(:ok)

      assert %{"profile_permission" => true} = permissions
    end

    setup :profile_source
    @tag authentication: [role: "user"]
    test "user with permission can profile structure with indirect profile source", %{
      conn: conn,
      claims: %{user_id: user_id},
      profile_domain: %{id: domain_id},
      structure: structure
    } do
      create_acl_entry(user_id, domain_id, [:view_data_structure, :profile_structures])

      assert %{"user_permissions" => permissions} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(
                   conn,
                   :show,
                   structure.id,
                   "latest"
                 )
               )
               |> json_response(:ok)

      assert %{"profile_permission" => true} = permissions
    end
  end

  describe "GET /api/data_structures/:id/versions/:version field structures" do
    setup :create_field_structure

    @tag authentication: [role: "user"]
    test "user whithout permission can not profile structure", %{
      conn: conn,
      claims: %{user_id: user_id},
      data_structure: %{id: id},
      domain: %{id: domain_id}
    } do
      create_acl_entry(user_id, domain_id, [:view_data_structure])

      assert %{"user_permissions" => permissions} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(conn, :show, id, "latest")
               )
               |> json_response(:ok)

      assert %{"profile_permission" => false} = permissions
    end

    @tag authentication: [role: "user"]
    test "user with permission can profile structure", %{
      conn: conn,
      claims: %{user_id: user_id},
      data_structure: %{id: id},
      domain: %{id: domain_id}
    } do
      create_acl_entry(user_id, domain_id, [:view_data_structure, :profile_structures])

      assert %{"user_permissions" => permissions} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(conn, :show, id, "latest")
               )
               |> json_response(:ok)

      assert %{"profile_permission" => true} = permissions
    end
  end

  describe "bulk_update" do
    @tag authentication: [role: "admin"]
    test "bulk update of data structures", %{conn: conn} do
      %{id: structure_id} = insert(:data_structure, external_id: "Structure")

      insert(:structure_note,
        data_structure_id: structure_id,
        df_content: %{"Field1" => "foo", "Field2" => "bar"}
      )

      insert(:data_structure_version, data_structure_id: structure_id)

      assert %{"data" => data} =
               conn
               |> post(Routes.data_structure_path(conn, :bulk_update), %{
                 "bulk_update_request" => %{
                   "update_attributes" => %{
                     "df_content" => %{
                       "Field1" => "hola soy field 1",
                       "Field2" => "hola soy field 2"
                     },
                     "otra_cosa" => 2
                   },
                   "search_params" => %{
                     "filters" => %{
                       "type.raw" => [
                         "Table"
                       ]
                     }
                   }
                 }
               })
               |> json_response(:ok)

      assert %{"message" => [^structure_id | _]} = data
    end

    @tag authentication: [role: "admin"]
    test "bulk update of data structures with no filter type", %{conn: conn} do
      %{id: structure_id} = insert(:data_structure, external_id: "Structure")
      insert(:data_structure_version, data_structure_id: structure_id)

      assert %{"data" => data} =
               conn
               |> post(Routes.data_structure_path(conn, :bulk_update), %{
                 "bulk_update_request" => %{
                   "update_attributes" => %{
                     "df_content" => %{
                       "Field1" => "hola soy field 1",
                       "Field2" => "hola soy field 2"
                     },
                     "otra_cosa" => 2
                   },
                   "search_params" => %{
                     "filters" => %{
                       "type.raw" => [
                         "Field"
                       ]
                     }
                   }
                 }
               })
               |> json_response(:ok)

      assert %{"message" => []} = data
    end
  end

  defp create_structure_hierarchy(_) do
    %{id: source_id} = create_source()

    parent_structure = insert(:data_structure, external_id: "Parent", source_id: source_id)
    structure = insert(:data_structure, external_id: "Structure", source_id: source_id)
    insert(:structure_metadata, data_structure_id: structure.id)

    child_structures = [
      insert(:data_structure, external_id: "Child1", source_id: source_id),
      insert(:data_structure, external_id: "Child2", source_id: source_id)
    ]

    parent_version = insert(:data_structure_version, data_structure_id: parent_structure.id)

    structure_version =
      insert(:data_structure_version, data_structure_id: structure.id, metadata: %{foo: "bar"})

    child_versions =
      Enum.map(
        child_structures,
        &insert(:data_structure_version, data_structure_id: &1.id, metadata: %{"order" => 1})
      )

    relation_type_id = RelationTypes.default_id!()

    insert(:data_structure_relation,
      parent_id: parent_version.id,
      child_id: structure_version.id,
      relation_type_id: relation_type_id
    )

    Enum.each(
      child_versions,
      &insert(:data_structure_relation,
        parent_id: structure_version.id,
        child_id: &1.id,
        relation_type_id: relation_type_id
      )
    )

    {:ok,
     parent_structure: parent_structure,
     structure_version: structure_version,
     structure: structure,
     child_structures: child_structures}
  end

  defp create_structure_hierarchy_with_logic_deletions(_) do
    deleted_at = "2019-06-14 11:00:00Z"
    parent = insert(:data_structure, external_id: "Parent")
    parent_deleted = insert(:data_structure, external_id: "Parent_deleted")

    children = [
      insert(:data_structure, external_id: "Child1"),
      insert(:data_structure, external_id: "Child2"),
      insert(:data_structure, external_id: "Child_deleted")
    ]

    parent_version =
      insert(:data_structure_version,
        data_structure_id: parent.id,
        name: parent.external_id,
        deleted_at: deleted_at
      )

    parent_version_deleted = insert(:data_structure_version, data_structure_id: parent_deleted.id)

    child_versions =
      Enum.map(
        children,
        &insert(:data_structure_version,
          data_structure_id: &1.id,
          name: &1.external_id,
          deleted_at: if(&1.external_id == "Child_deleted", do: deleted_at, else: nil)
        )
      )

    relation_type_id = RelationTypes.default_id!()

    Enum.each(
      child_versions,
      &insert(:data_structure_relation,
        parent_id: parent_version.id,
        child_id: &1.id,
        relation_type_id: relation_type_id
      )
    )

    Enum.each(
      child_versions,
      &insert(:data_structure_relation,
        parent_id: parent_version_deleted.id,
        child_id: &1.id,
        relation_type_id: relation_type_id
      )
    )

    {:ok, parent_structure: parent, child_structures: children}
  end

  defp create_field_structure(_) do
    domain = CacheHelpers.insert_domain()
    %{id: source_id} = create_source()

    data_structure = insert(:data_structure, domain_id: domain.id, source_id: source_id)

    data_structure_version =
      insert(:data_structure_version,
        data_structure_id: data_structure.id,
        type: "Column",
        class: "field"
      )

    {:ok,
     domain: domain,
     data_structure: data_structure,
     data_structure_version: data_structure_version}
  end

  defp create_data_field_structure(_) do
    domain = CacheHelpers.insert_domain()
    %{id: source_id} = create_source()

    data_structure = insert(:data_structure, domain_id: domain.id, source_id: source_id)

    data_structure_version =
      insert(:data_structure_version,
        data_structure_id: data_structure.id,
        type: "Table"
      )

    {:ok, field_data} = create_field_structure([])
    field = Keyword.get(field_data, :data_structure_version)

    insert(:data_structure_relation,
      parent_id: data_structure_version.id,
      child_id: field.id,
      relation_type_id: RelationTypes.default_id!()
    )

    {:ok,
     domain: domain,
     data_structure: data_structure,
     data_structure_version: data_structure_version}
  end

  defp create_source do
    insert(:source, config: %{"job_types" => ["catalog", "profile"]})
  end

  defp profile_source(_) do
    domain = build(:domain)
    TaxonomyCache.put_domain(domain)
    on_exit(fn -> TaxonomyCache.delete_domain(domain.id) end)

    s1 =
      insert(:source, external_id: "foo", config: %{"job_types" => ["catalog"], "alias" => "foo"})

    insert(:source, external_id: "bar", config: %{"job_types" => ["profile"], "alias" => "foo"})
    structure = insert(:data_structure, domain_id: domain.id, source_id: s1.id)

    insert(:data_structure_version,
      data_structure_id: structure.id,
      type: "Column",
      class: "field"
    )

    {:ok, structure: structure, profile_domain: domain}
  end
end
