defmodule TdDdWeb.DataStructureVersionControllerTest do
  use TdDd.DataStructureCase
  use TdDdWeb.ConnCase
  use PhoenixSwagger.SchemaTest, "priv/static/swagger.json"

  import Mox

  alias TdDd.DataStructures.Hierarchy
  alias TdDd.DataStructures.RelationTypes

  @moduletag sandbox: :shared

  setup_all do
    start_supervised!(TdDd.Lineage.GraphData)
    start_supervised!(TdDd.Search.Cluster)
    :ok
  end

  setup :verify_on_exit!

  setup do
    start_supervised!(TdDd.Search.StructureEnricher)
    insert(:system, id: 1)

    type = "Table"

    %{id: template_id} =
      template =
      CacheHelpers.insert_template(
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
              },
              %{
                "name" => "alias",
                "type" => "string"
              }
            ]
          }
        ],
        scope: "test",
        label: "template_label"
      )

    CacheHelpers.insert_structure_type(template_id: template_id, name: type)

    [template: template]
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
    test "renders a data structure with merged metadata", %{
      conn: conn,
      structure: %{id: id},
      structure_version: %{metadata: metadata},
      mutable_metadata: mutable_metadata
    } do
      assert %{"data" => %{"metadata" => merged_metadata}} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(conn, :show, id, "latest")
               )
               |> json_response(:ok)

      assert merged_metadata == Map.merge(metadata, mutable_metadata)
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
      start_date = Date.utc_today() |> Date.add(-1)
      end_date = Date.utc_today() |> Date.add(1)

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

      start_date_string = Date.to_iso8601(start_date)
      end_date_string = Date.to_iso8601(end_date)

      assert %{
               "id" => ^id,
               "end_date" => ^end_date_string,
               "start_date" => ^start_date_string,
               "detail" => ^detail,
               "user_id" => ^user_id,
               "data_structure" => %{
                 "id" => ^data_structure_id,
                 "external_id" => ^data_structure_external_id
               },
               "data_structure_version" => %{"name" => ^data_structure_name, "ancestry" => _},
               "system" => %{"external_id" => _, "id" => _, "name" => _}
             } = grant
    end

    @tag authentication: [role: "admin"]
    test "renders a data structure with grant from parent", %{
      conn: conn,
      structure: structure,
      parent_structure: parent_structure,
      claims: %{user_id: user_id}
    } do
      start_date = Date.utc_today() |> Date.add(-1)
      end_date = Date.utc_today() |> Date.add(1)

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

      start_date_string = Date.to_iso8601(start_date)
      end_date_string = Date.to_iso8601(end_date)

      assert %{
               "id" => ^id,
               "end_date" => ^end_date_string,
               "start_date" => ^start_date_string,
               "detail" => ^detail,
               "user_id" => ^user_id,
               "data_structure" => %{"id" => _, "external_id" => _},
               "data_structure_version" => %{"name" => _, "ancestry" => _},
               "system" => %{"external_id" => _, "id" => _, "name" => _}
             } = grant
    end

    @tag authentication: [role: "admin"]
    test "renders a data structure without future grant", %{
      conn: conn,
      structure: structure,
      claims: %{user_id: user_id}
    } do
      start_date = Date.utc_today() |> Date.add(1)
      end_date = Date.utc_today() |> Date.add(2)

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
      start_date = Date.utc_today() |> Date.add(-1)
      end_date = Date.utc_today() |> Date.add(1)

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

      start_date_string = Date.to_iso8601(start_date)
      end_date_string = Date.to_iso8601(end_date)

      assert %{
               "id" => ^id,
               "end_date" => ^end_date_string,
               "start_date" => ^start_date_string,
               "detail" => ^detail,
               "data_structure" => %{
                 "id" => ^data_structure_id,
                 "external_id" => ^data_structure_external_id
               },
               "data_structure_version" => %{
                 "name" => ^data_structure_name,
                 "ancestry" => [_ | _]
               },
               "system" => %{"external_id" => _, "id" => _, "name" => _}
             } = grant
    end

    @tag authentication: [role: "non_admin", permissions: [:view_data_structure]]
    test "renders a data structure without grants when user has not permissions", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      structure = insert(:data_structure, domain_ids: [domain_id])
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
      [
        %{id: foo_dsv_id, data_structure_id: foo_id},
        %{id: bar_dsv_id, data_structure_id: bar_id},
        _baz,
        %{id: qux_dsv_id, data_structure_id: qux_id}
      ] = create_hierarchy(["foo", "bar", "baz", "qux"], domain_id: domain_id)

      Hierarchy.update_hierarchy([foo_dsv_id, bar_dsv_id, qux_dsv_id])

      start_date = Date.utc_today() |> Date.add(-1) |> Date.to_iso8601()
      end_date = Date.utc_today() |> Date.add(1) |> Date.to_iso8601()

      %{id: id, detail: detail} =
        insert(:grant,
          data_structure_id: bar_id,
          start_date: Date.from_iso8601!(start_date),
          end_date: Date.from_iso8601!(end_date)
        )

      assert %{"data" => %{"grants" => [grant]}} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(conn, :show, qux_id, "latest")
               )
               |> json_response(:ok)

      assert %{
               "id" => ^id,
               "end_date" => ^end_date,
               "start_date" => ^start_date,
               "detail" => ^detail,
               "data_structure" => %{
                 "id" => ^bar_id,
                 "external_id" => _
               },
               "data_structure_version" => %{
                 "name" => "bar",
                 "ancestry" => ancestry = [_ | _]
               },
               "system" => %{"external_id" => _, "id" => _, "name" => _}
             } = grant

      assert [%{"data_structure_id" => ^foo_id, "name" => "foo"}] = ancestry

      assert %{"data" => %{"grants" => []}} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(conn, :show, foo_id, "latest")
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

  describe "GET /api/data_structures/:id/versions/latest with actions" do
    @tag authentication: [role: "admin"]
    test "includes actions in the response", %{conn: conn} do
      %{id: tag_id, name: tag_name, description: tag_description} = insert(:data_structure_tag)
      %{data_structure_id: id, version: version} = insert(:data_structure_version)

      for v <- ["latest", version] do
        assert %{"_actions" => actions} =
                 conn
                 |> get(Routes.data_structure_data_structure_version_path(conn, :show, id, v))
                 |> json_response(:ok)

        assert %{"manage_tags" => %{"data" => [tag]}} = actions
        assert %{"id" => ^tag_id, "name" => ^tag_name, "description" => ^tag_description} = tag
      end
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
    setup :create_table_structure
    setup :profile_source

    @tag authentication: [role: "user", permissions: [:view_data_structure]]
    test "user without permission can not profile structure", %{
      conn: conn,
      data_structure: %{id: id}
    } do
      assert %{"user_permissions" => permissions} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(conn, :show, id, "latest")
               )
               |> json_response(:ok)

      assert %{"profile_permission" => false} = permissions
    end

    @tag authentication: [role: "user", permissions: [:view_data_structure, :profile_structures]]
    test "user with permission can profile structure", %{
      conn: conn,
      data_structure: %{id: id}
    } do
      assert %{"user_permissions" => permissions} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(conn, :show, id, "latest")
               )
               |> json_response(:ok)

      assert %{"profile_permission" => true} = permissions
    end

    @tag authentication: [role: "user", permissions: [:view_data_structure, :profile_structures]]
    test "user with permission can profile structure with indirect profile source", %{
      conn: conn,
      structure: structure
    } do
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

    @tag authentication: [
           role: "user",
           permissions: [:view_data_structure, :create_grant_request]
         ]
    test "user with permission can request grant", %{
      conn: conn,
      data_structure: %{id: id}
    } do
      CacheHelpers.insert_template(%{name: "foo", label: "foo", scope: "gr", content: []})

      assert %{"user_permissions" => permissions} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(conn, :show, id, "latest")
               )
               |> json_response(:ok)

      assert %{"request_grant" => true} = permissions
    end

    @tag authentication: [role: "user", permissions: [:view_data_structure]]
    test "user without permission can not request grant", %{
      conn: conn,
      data_structure: %{id: id}
    } do
      assert %{"user_permissions" => permissions} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(conn, :show, id, "latest")
               )
               |> json_response(:ok)

      assert %{"request_grant" => false} = permissions
    end

    @tag authentication: [
           role: "user",
           permissions: [:view_data_structure, :request_grant_removal]
         ]
    test "user with permission can update grant removal", %{
      conn: conn,
      data_structure: %{id: id}
    } do
      CacheHelpers.insert_template(%{name: "foo", label: "foo", scope: "gr", content: []})

      assert %{"user_permissions" => permissions} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(conn, :show, id, "latest")
               )
               |> json_response(:ok)

      assert %{"update_grant_removal" => true} = permissions
    end

    @tag authentication: [role: "user", permissions: [:view_data_structure]]
    test "user without permission can not update grant removal", %{
      conn: conn,
      data_structure: %{id: id}
    } do
      assert %{"user_permissions" => permissions} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(conn, :show, id, "latest")
               )
               |> json_response(:ok)

      assert %{"update_grant_removal" => false} = permissions
    end

    @tag authentication: [
           role: "user",
           permissions: [:view_data_structure, :create_grant_request]
         ]
    test "cannot request grant without template", %{
      conn: conn,
      data_structure: %{id: id}
    } do
      assert %{"user_permissions" => permissions} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(conn, :show, id, "latest")
               )
               |> json_response(:ok)

      assert %{"request_grant" => false} = permissions
    end
  end

  describe "GET /api/data_structures/:id/versions/:version field structures" do
    setup :create_field_structure

    @tag authentication: [role: "user", permissions: [:view_data_structure]]
    test "user without permission can not profile structure", %{
      conn: conn,
      data_structure: %{id: id}
    } do
      assert %{"user_permissions" => permissions} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(conn, :show, id, "latest")
               )
               |> json_response(:ok)

      assert %{"profile_permission" => false} = permissions
    end

    @tag authentication: [role: "user", permissions: [:view_data_structure, :profile_structures]]
    test "user with permission can profile structure", %{
      conn: conn,
      data_structure: %{id: id}
    } do
      assert %{"user_permissions" => permissions} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(conn, :show, id, "latest")
               )
               |> json_response(:ok)

      assert %{"profile_permission" => true} = permissions
    end
  end

  describe "GET /api/data_structures/:id/versions/:version with notes" do
    setup :create_structure_with_published_note

    @tag authentication: [role: "admin"]
    test "return only published note content matched with the template", %{
      conn: conn,
      data_structure_version: %{data_structure_id: id},
      published_note: %{df_content: %{"Field1" => field_1, "alias" => content_alias}}
    } do
      assert %{"data" => %{"published_note" => note}} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(conn, :show, id, "latest")
               )
               |> json_response(:ok)

      assert note == %{"Field1" => field_1, "alias" => content_alias}
    end

    @tag authentication: [role: "admin"]
    test "children renders published note", %{
      conn: conn,
      data_structure_version: structure_version,
      published_note: %{df_content: %{"alias" => content_alias}}
    } do
      %{data_structure_id: parent_structure_id} = parent_version = insert(:data_structure_version)

      relation_type_id = RelationTypes.default_id!()

      insert(:data_structure_relation,
        parent_id: parent_version.id,
        child_id: structure_version.id,
        relation_type_id: relation_type_id
      )

      assert %{"data" => %{"children" => [%{"published_note" => note}]}} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(
                   conn,
                   :show,
                   parent_structure_id,
                   "latest"
                 )
               )
               |> json_response(:ok)

      assert note == %{"alias" => content_alias}
    end

    @tag authentication: [role: "admin"]
    test "siblings renders published note", %{
      conn: conn,
      data_structure_version: structure_version,
      published_note: %{df_content: %{"alias" => content_alias}}
    } do
      parent_version = insert(:data_structure_version)

      %{data_structure_id: sibling_structure_id} =
        sibling_version = insert(:data_structure_version)

      relation_type_id = RelationTypes.default_id!()

      insert(:data_structure_relation,
        parent_id: parent_version.id,
        child_id: structure_version.id,
        relation_type_id: relation_type_id
      )

      insert(:data_structure_relation,
        parent_id: parent_version.id,
        child_id: sibling_version.id,
        relation_type_id: relation_type_id
      )

      assert %{"data" => %{"siblings" => [%{"published_note" => note}, _]}} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(
                   conn,
                   :show,
                   sibling_structure_id,
                   "latest"
                 )
               )
               |> json_response(:ok)

      assert note == %{"alias" => content_alias}
    end
  end

  describe "GET /api/data_structures/:id/versions/:version implementations" do
    setup :create_structure_with_implementation

    @tag authentication: [role: "admin"]
    test "rendes related implementations", %{
      conn: conn,
      data_structure: %{id: id},
      implementation: %{implementation_key: implementation_key},
      implementation_structure: %{id: implementation_structure_id}
    } do
      assert %{"data" => data} =
               conn
               |> get(
                 Routes.data_structure_data_structure_version_path(conn, :show, id, "latest")
               )
               |> json_response(:ok)

      assert %{
               "implementations" => [
                 %{
                   "id" => ^implementation_structure_id,
                   "implementation" => %{"implementation_key" => ^implementation_key}
                 }
               ]
             } = data
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

      dsv = insert(:data_structure_version, data_structure_id: structure_id)

      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", %{query: query}, _ ->
        assert query == %{
                 bool: %{
                   filter: %{term: %{"type.raw" => "Table"}},
                   must_not: %{exists: %{field: "deleted_at"}}
                 }
               }

        SearchHelpers.hits_response([dsv])
      end)

      assert %{"errors" => [], "ids" => [^structure_id | _]} =
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
    end

    @tag authentication: [role: "admin"]
    test "bulk update of data structures with no filter type", %{conn: conn} do
      ElasticsearchMock
      |> expect(:request, fn _, :post, "/structures/_search", %{query: query}, _ ->
        assert query == %{
                 bool: %{
                   filter: %{term: %{"type.raw" => "Field"}},
                   must_not: %{exists: %{field: "deleted_at"}}
                 }
               }

        SearchHelpers.hits_response([])
      end)

      %{id: structure_id} = insert(:data_structure, external_id: "Structure")
      insert(:data_structure_version, data_structure_id: structure_id)

      assert %{"errors" => [], "ids" => []} =
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
    end
  end

  defp create_structure_hierarchy(_) do
    %{id: source_id} = insert(:source, config: %{"job_types" => ["catalog", "profile"]})

    %{data_structure: parent_structure} =
      parent_version =
      insert(
        :data_structure_version,
        metadata: %{"foo" => "foo"},
        data_structure: build(:data_structure, external_id: "Parent", source_id: source_id)
      )

    %{data_structure: structure} =
      structure_version =
      insert(
        :data_structure_version,
        metadata: %{"bar" => "bar"},
        data_structure: build(:data_structure, external_id: "Structure", source_id: source_id)
      )

    mutable_metadata = %{"xyzzy" => "xyzzy"}
    insert(:structure_metadata, data_structure_id: structure.id, fields: mutable_metadata)

    child_structures = [
      insert(:data_structure, external_id: "Child1", source_id: source_id),
      insert(:data_structure, external_id: "Child2", source_id: source_id)
    ]

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

    [structure_version | child_versions]
    |> Enum.map(fn chv -> chv.id end)
    |> Hierarchy.update_hierarchy()

    [
      child_structures: child_structures,
      mutable_metadata: mutable_metadata,
      parent_structure: parent_structure,
      parent_version: parent_version,
      structure_version: structure_version,
      structure: structure
    ]
  end

  defp create_structure_with_implementation(_) do
    %{data_structure: data_structure} = insert(:data_structure_version)

    implementation = insert(:implementation)

    implementation_structure =
      insert(:implementation_structure,
        implementation: implementation,
        data_structure: data_structure
      )

    [
      implementation: implementation,
      data_structure: data_structure,
      implementation_structure: implementation_structure
    ]
  end

  defp create_structure_with_published_note(_) do
    %{data_structure: data_structure} = data_structure_version = insert(:data_structure_version)

    note =
      insert(:structure_note,
        data_structure: data_structure,
        df_content: %{"Field1" => "xyzzy", "list" => "two", "alias" => "some alias"},
        status: :published
      )

    [
      published_note: note,
      data_structure_version: data_structure_version
    ]
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

  defp create_field_structure(%{domain: domain}) do
    %{id: source_id} = insert(:source, config: %{"job_types" => ["catalog", "profile"]})

    data_structure = insert(:data_structure, domain_ids: [domain.id], source_id: source_id)

    data_structure_version =
      insert(:data_structure_version,
        data_structure_id: data_structure.id,
        type: "Column",
        class: "field"
      )

    [
      domain: domain,
      data_structure: data_structure,
      data_structure_version: data_structure_version
    ]
  end

  defp create_table_structure(%{domain: domain}) do
    %{id: source_id} = insert(:source, config: %{"job_types" => ["catalog", "profile"]})

    %{data_structure: data_structure} =
      data_structure_version =
      insert(:data_structure_version,
        data_structure: build(:data_structure, domain_ids: [domain.id], source_id: source_id),
        type: "Table"
      )

    %{id: field_id} =
      create_field_structure(%{domain: domain})
      |> Keyword.get(:data_structure_version)

    insert(:data_structure_relation,
      parent_id: data_structure_version.id,
      child_id: field_id,
      relation_type_id: RelationTypes.default_id!()
    )

    [data_structure: data_structure, data_structure_version: data_structure_version]
  end

  defp profile_source(%{domain: domain}) do
    source =
      insert(:source, external_id: "foo", config: %{"job_types" => ["catalog"], "alias" => "foo"})

    insert(:source, external_id: "bar", config: %{"job_types" => ["profile"], "alias" => "foo"})

    %{data_structure: structure} =
      insert(:data_structure_version,
        data_structure: build(:data_structure, domain_ids: [domain.id], source_id: source.id),
        type: "Column",
        class: "field"
      )

    [structure: structure, profile_domain: domain]
  end
end
