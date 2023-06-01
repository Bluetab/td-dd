defmodule TdDdWeb.Schema.StructuresTest do
  use TdDdWeb.ConnCase
  use TdDd.GraphDataCase

  alias TdDd.DataStructures.Hierarchy
  alias TdDd.DataStructures.RelationTypes
  alias TdDd.Lineage.GraphData
  alias TdDd.Lineage.GraphData.State

  @moduletag sandbox: :shared

  @query """
  query DataStructureVersions($since: DateTime) {
    dataStructureVersions(since: $since) {
      id
      metadata
      name
      dataStructure {
        id
        externalId
        domainId
        domainIds
        system {
          id
          externalId
        }
        updated_at
      }
      parents {
        id
      }
    }
  }
  """

  @path_query """
  query DataStructureVersions {
    dataStructureVersions {
      id
      name
      path
    }
  }
  """

  @relations_query """
  query DataStructureRelations($since: DateTime, $types: [String]) {
    dataStructureRelations(since: $since, types: $types) {
      id
      parentId
      childId
      relationTypeId
      parent {
        id
      }
      child {
        id
      }
      relationType {
        id
      }
    }
  }
  """

  @version_query """
  query DataStructureVersion($dataStructureId: ID!, $version: String!, $note_fields: [String]) {
    dataStructureVersion(dataStructureId: $dataStructureId, version: $version) {
      id
      version
      class
      description
      name
      type
      group
      deleted_at
      metadata
      dataStructure {
        id
        alias
        confidential
        domain_ids
        domains {
          id
          name
          parents {
            id
          }
        }
        external_id
        inserted_at
        updated_at
      }
      parents { dataStructure { external_id } }
      children {
        dataStructure { external_id }
        classes
        }
      siblings { dataStructure { external_id } }
      versions {
        version
        dataStructure { external_id }
      }
      ancestry

      classes
      implementation_count
      data_structure_link_count

      note
      profile {
        max
        min
        null_count
        most_frequent
        value
      }
      source {
        id
        external_id
      }
      system {
        id
        name
      }
      structure_type {
        metadata_views {
          name
          fields
        }
        template_id
        translation
      }
      degree {
        in
        out
      }
      grants { id }
      grant { id }

      data_fields {
        note(select_fields: $note_fields)
        data_structure_id
        id
        type
        profile {
          max
          min
          most_frequent
          null_count
        }
        links
      }
      relations {
        parents {
          id
          structure  { id }
          relation_type { name }
        }
        children {
          id
          structure  { id }
          relation_type { name }
        }

      }

      links
      _actions
      user_permissions
    }
  }
  """

  @permissions_domains_query """
  query DataStructureVersion($dataStructureId: ID!, $version: String!) {
    dataStructureVersion(dataStructureId: $dataStructureId, version: $version) {
      id
      dataStructure {
        id
        domain_ids
        domains { id,name }
      }
      children {
        dataStructure {
          external_id
          id
          domain_ids
          domains { id,name }
        }
      }
      siblings {
        dataStructure {
          external_id
          id
          domain_ids
          domains { id,name }
        }
      }
    }
  }
  """

  @domains_herarchy_query """
  query DataStructureVersion($dataStructureId: ID!, $version: String!) {
    dataStructureVersion(dataStructureId: $dataStructureId, version: $version) {
      id
      version
      name
      dataStructure {
        id
        domain_ids
        domains {
          id
          parent_id
          parents {
            id
          }
        }
      }
    }
  }
  """

  @alias_children_query """
  query DataStructureVersion($dataStructureId: ID!, $version: String!) {
    dataStructureVersion(dataStructureId: $dataStructureId, version: $version) {
      id
      children {
        alias
        id
      }
      data_fields {
        data_structure_id
        id
        type
        alias
      }
    }
  }
  """

  @alias_siblings_query """
  query DataStructureVersion($dataStructureId: ID!, $version: String!) {
    dataStructureVersion(dataStructureId: $dataStructureId, version: $version) {
      id
      siblings {
        alias
        id
      }
    }
  }
  """

  @variables %{"since" => "2020-01-01T00:00:00Z"}
  @metadata %{"foo" => ["bar"]}

  setup do
    start_supervised!(TdDd.Search.StructureEnricher)
    start_supervised(GraphData)
    :ok
  end

  describe "dataStructureVersions query" do
    @tag authentication: [role: "user"]
    test "returns forbidden when queried by user role", %{conn: conn} do
      assert %{"data" => data, "errors" => errors} =
               conn
               |> post("/api/v2", %{"query" => @query, "variables" => @variables})
               |> json_response(:ok)

      assert data == %{"dataStructureVersions" => nil}
      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "service"]
    test "returns data when queried by service role", %{conn: conn} do
      %{id: expected_id_1, name: name_1} =
        insert(:data_structure_version,
          updated_at: ~U[2019-01-01T00:00:00Z],
          deleted_at: ~U[2019-01-01T00:00:00Z]
        )

      %{id: expected_id_2, name: name_2} =
        insert(:data_structure_version, metadata: @metadata, domain_ids: [1, 2])

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{"query" => @query, "variables" => @variables})
               |> json_response(:ok)

      assert response["errors"] == nil
      assert %{"dataStructureVersions" => data_structure_versions} = data

      assert [
               %{
                 "id" => id_1,
                 "dataStructure" => %{"updated_at" => dsv_1_updated_at},
                 "name" => ^name_1
               },
               %{
                 "id" => id_2,
                 "dataStructure" => data_structure_2,
                 "metadata" => @metadata,
                 "name" => ^name_2
               }
             ] = data_structure_versions

      assert id_1 == to_string(expected_id_1)
      assert id_2 == to_string(expected_id_2)

      %{"since" => since} = @variables
      assert {:ok, datetime_dsv_1_updated_at, 0} = DateTime.from_iso8601(dsv_1_updated_at)
      assert {:ok, datetime_since, 0} = DateTime.from_iso8601(since)
      assert DateTime.compare(datetime_dsv_1_updated_at, datetime_since) in [:gt, :eq]

      assert %{
               "id" => _,
               "externalId" => _,
               "system" => system,
               "domainId" => 1,
               "domainIds" => [1, 2]
             } = data_structure_2

      assert %{"id" => _, "externalId" => _} = system
    end

    @tag authentication: [role: "service"]
    test "can query parents, excludes deleted parents", %{conn: conn} do
      %{parent_id: parent_id} = insert(:data_structure_relation)

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{"query" => @query, "variables" => @variables})
               |> json_response(:ok)

      assert response["errors"] == nil
      assert %{"dataStructureVersions" => data_structure_versions} = data

      assert Enum.any?(data_structure_versions, &(%{"id" => "#{parent_id}"} in &1["parents"]))
    end

    @tag authentication: [role: "service"]
    test "excludes deleted parents", %{conn: conn} do
      %{id: parent_id} = insert(:data_structure_version, deleted_at: DateTime.utc_now())
      insert(:data_structure_relation, parent_id: parent_id)

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{"query" => @query, "variables" => @variables})
               |> json_response(:ok)

      assert response["errors"] == nil
      assert %{"dataStructureVersions" => data_structure_versions} = data

      refute Enum.any?(data_structure_versions, &(%{"id" => "#{parent_id}"} in &1["parents"]))
    end

    @tag authentication: [role: "service"]
    test "returns correct path for structure version", %{conn: conn} do
      domain_id = System.unique_integer([:positive])
      %{id: system_id} = insert(:system)

      %{id: child_id} =
        insert(:data_structure_version,
          name: "child",
          data_structure:
            build(:data_structure,
              external_id: "child",
              system_id: system_id,
              domain_ids: [domain_id]
            )
        )

      %{id: default_parent_id} =
        insert(:data_structure_version,
          name: "default_parent",
          data_structure:
            build(:data_structure,
              external_id: "default_parent",
              system_id: system_id,
              domain_ids: [domain_id]
            )
        )

      %{id: other_parent_id} =
        insert(:data_structure_version,
          name: "other_parent",
          data_structure:
            build(:data_structure,
              external_id: "other_parent",
              system_id: system_id,
              domain_ids: [domain_id]
            )
        )

      default_relation_id = RelationTypes.default_id!()
      %{id: custom_relation_id} = insert(:relation_type, name: "relation_type_1")

      insert(:data_structure_relation,
        parent_id: default_parent_id,
        child_id: child_id,
        relation_type_id: default_relation_id
      )

      insert(:data_structure_relation,
        parent_id: other_parent_id,
        child_id: child_id,
        relation_type_id: custom_relation_id
      )

      Hierarchy.update_hierarchy([child_id])

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{"query" => @path_query})
               |> json_response(:ok)

      assert response["errors"] == nil
      assert %{"dataStructureVersions" => data_structure_versions} = data

      assert [
               %{
                 "id" => id,
                 "name" => "child",
                 "path" => ["default_parent"]
               },
               %{"name" => "default_parent"},
               %{"name" => "other_parent"}
             ] = data_structure_versions

      assert id == to_string(child_id)
    end
  end

  describe "dataStructureVersion query" do
    @tag authentication: [role: "admin"]
    @tag contains: %{}
    @tag depends: []
    test "returns required data when queried by admin", %{conn: conn, claims: %{user_id: user_id}} do
      %{id: father_domain_id} = father_domain = CacheHelpers.insert_domain()

      %{id: domain_id, name: domain_name} =
        CacheHelpers.insert_domain(parent_id: father_domain_id, parents: [father_domain])

      %{id: source_id, external_id: source_external_id} = source = insert(:source)
      %{id: system_id, name: system_name} = system = insert(:system)

      %{
        name: type_name,
        template_id: structure_type_template_id,
        metadata_views: [%{fields: metadata_view_fields, name: metadata_view_name}],
        translation: structure_type_translation
      } = insert(:data_structure_type)

      metadata_view = %{"fields" => metadata_view_fields, "name" => metadata_view_name}

      %{
        id: data_structure_id,
        inserted_at: ds_timestamp,
        external_id: external_id
      } =
        data_structure =
        insert(:data_structure,
          source: source,
          system: system,
          domain_ids: [domain_id]
        )

      ## Structure versions
      insert(:data_structure_version, data_structure: data_structure)

      %{
        id: id,
        name: name,
        description: description,
        group: group
      } =
        insert(:data_structure_version,
          class: "table",
          data_structure: data_structure,
          type: type_name,
          version: 1
        )

      another_data_structure = insert(:data_structure)

      ## Structure class
      %{class: class_value, name: class_name} =
        insert(:structure_classification, data_structure_version_id: id)

      insert(:implementation_structure, data_structure_id: data_structure_id)

      structure_class = fn
        %{external_id: "child"} -> "field"
        %{external_id: "non_default_child"} -> "field"
        _ -> nil
      end

      ## Structure relations
      [
        %{id: parent_dsv_id, name: parent_dsv_name, data_structure_id: parent_ds_id} = parent,
        %{data_structure_id: child_ds_id, id: child_id} = child,
        sibling,
        %{id: nodef_parent_dsv_id} = non_default_parent,
        %{data_structure_id: nodef_child_ds_id, id: nodef_child_dsv_id} = non_default_child
      ] =
        ["parent", "child", "sibling", "non_default_parent", "non_default_child"]
        |> Enum.map(&insert(:data_structure, external_id: &1))
        |> Enum.map(
          &insert(:data_structure_version, data_structure_id: &1.id, class: structure_class.(&1))
        )

      %{class: class_value_child, name: class_name_child} =
        insert(:structure_classification, data_structure_version_id: child_id)

      %{id: custom_relation_type_id, name: custom_relation_type_name} =
        insert(:relation_type, name: "relation_type_1")

      create_relation(parent.id, id)
      create_relation(parent.id, sibling.id)
      create_relation(id, child.id)

      %{id: parent_relation_id} =
        create_relation(non_default_parent.id, id, custom_relation_type_id)

      %{id: child_relation_id} =
        create_relation(id, non_default_child.id, custom_relation_type_id)

      ## Structure Note
      insert(:structure_note,
        data_structure_id: data_structure_id,
        df_content: %{"foo" => "bar"},
        status: :published
      )

      insert(:structure_note,
        data_structure_id: child_ds_id,
        df_content: %{
          "foo" => "bar",
          "child_field" => "value1",
          "not_selected_field" => "value2"
        },
        status: :published
      )

      ## Structure Profile
      insert(:profile,
        data_structure_id: data_structure_id,
        min: "1",
        max: "2",
        null_count: 5,
        most_frequent: ~s([["A", "76"]])
      )

      insert(:profile,
        data_structure_id: child_ds_id,
        min: "3",
        max: "5",
        null_count: 0,
        most_frequent: ~s([["A", "22"]])
      )

      test_label = insert(:label, name: "test_label")

      ## Structure link
      insert(:data_structure_link,
        source: data_structure,
        target: another_data_structure,
        labels: [test_label]
      )

      ### Graph
      contains = %{"foo" => [external_id, "baz"]}
      depends = [{external_id, "baz"}]
      GraphData.state(state: setup_state(%{contains: contains, depends: depends}))

      ## Hierarchy
      Hierarchy.update_hierarchy([id, parent_dsv_id])

      ## Concepts relations
      %{id: concept_id, name: concept_name} = CacheHelpers.insert_concept()

      %{id: link_id} =
        CacheHelpers.insert_link(
          data_structure_id,
          "data_structure",
          "business_concept",
          concept_id
        )

      %{id: child_concept_id, name: child_concept_name} = CacheHelpers.insert_concept()

      %{id: child_link_id} =
        CacheHelpers.insert_link(
          child_ds_id,
          "data_structure",
          "business_concept",
          child_concept_id
        )

      ## Grants
      start_date = Date.utc_today() |> Date.add(-1)
      end_date = Date.utc_today() |> Date.add(2)

      %{id: grant_id} =
        insert(:grant,
          data_structure_id: data_structure_id,
          user_id: user_id,
          start_date: start_date,
          end_date: end_date
        )

      variables = %{
        "dataStructureId" => data_structure_id,
        "note_fields" => ["foo", "child_field"],
        "version" => "latest"
      }

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @version_query,
                 "variables" => variables
               })
               |> json_response(:ok)

      string_timestamp = DateTime.to_iso8601(ds_timestamp)
      assert response["errors"] == nil

      assert %{
               "dataStructureVersion" => %{
                 "_actions" => %{
                   "create_link" => %{},
                   "create_struct_to_struct_link" => %{
                     "href" => "/api/v2",
                     "method" => "POST"
                   }
                 },
                 "class" => "table",
                 "dataStructure" => %{
                   "alias" => nil,
                   "confidential" => false,
                   "domain_ids" => [domain_id],
                   "domains" => [
                     %{
                       "id" => "#{domain_id}",
                       "name" => domain_name,
                       "parents" => [
                         %{
                           "id" => "#{father_domain_id}"
                         }
                       ]
                     }
                   ],
                   "external_id" => external_id,
                   "id" => "#{data_structure_id}",
                   "inserted_at" => string_timestamp,
                   "updated_at" => string_timestamp
                 },
                 "deleted_at" => nil,
                 "name" => name,
                 "description" => description,
                 "group" => group,
                 "id" => "#{id}",
                 "metadata" => %{"description" => "some description"},
                 "parents" => [
                   %{"dataStructure" => %{"external_id" => "parent"}},
                   %{"dataStructure" => %{"external_id" => "non_default_parent"}}
                 ],
                 "children" => [
                   %{
                     "dataStructure" => %{"external_id" => "child"},
                     "classes" => %{class_name_child => class_value_child}
                   },
                   %{"dataStructure" => %{"external_id" => "non_default_child"}, "classes" => nil}
                 ],
                 "siblings" => [
                   %{"dataStructure" => %{"external_id" => external_id}},
                   %{"dataStructure" => %{"external_id" => "sibling"}}
                 ],
                 "versions" => [
                   %{"dataStructure" => %{"external_id" => external_id}, "version" => 0},
                   %{"dataStructure" => %{"external_id" => external_id}, "version" => 1}
                 ],
                 "type" => type_name,
                 "version" => 1,
                 "classes" => %{class_name => class_value},
                 "implementation_count" => 1,
                 "data_structure_link_count" => 1,
                 "note" => %{"foo" => "bar"},
                 "profile" => %{
                   "max" => "2",
                   "min" => "1",
                   "most_frequent" => [%{"k" => "A", "v" => 76}],
                   "null_count" => 5,
                   "value" => %{"foo" => "bar"}
                 },
                 "source" => %{
                   "id" => "#{source_id}",
                   "external_id" => source_external_id
                 },
                 "system" => %{
                   "id" => "#{system_id}",
                   "name" => system_name
                 },
                 "structure_type" => %{
                   "template_id" => structure_type_template_id,
                   "metadata_views" => [metadata_view],
                   "translation" => structure_type_translation
                 },
                 "degree" => %{"in" => 0, "out" => 1},
                 "ancestry" => [
                   %{"data_structure_id" => parent_ds_id, "name" => parent_dsv_name}
                 ],
                 "links" => [
                   %{
                     "concept_count" => 0,
                     "content" => %{},
                     "domain" => nil,
                     "domain_id" => nil,
                     "id" => "#{link_id}",
                     "link_count" => 1,
                     "link_tags" => [],
                     "name" => "#{concept_name}",
                     "resource_id" => "#{concept_id}",
                     "resource_type" => "concept",
                     "rule_count" => 0,
                     "shared_to" => [],
                     "shared_to_ids" => [],
                     "tags" => []
                   }
                 ],
                 "grant" => %{"id" => "#{grant_id}"},
                 "grants" => [%{"id" => "#{grant_id}"}],
                 "data_fields" => [
                   %{
                     "note" => %{
                       "child_field" => "value1",
                       "foo" => "bar"
                     },
                     "data_structure_id" => "#{child_ds_id}",
                     "id" => "#{child_id}",
                     "type" => "Table",
                     "profile" => %{
                       "max" => "5",
                       "min" => "3",
                       "most_frequent" => [%{"k" => "A", "v" => 22}],
                       "null_count" => 0
                     },
                     "links" => [
                       %{
                         "concept_count" => 0,
                         "content" => %{},
                         "domain" => nil,
                         "domain_id" => nil,
                         "id" => "#{child_link_id}",
                         "link_count" => 1,
                         "link_tags" => [],
                         "name" => "#{child_concept_name}",
                         "resource_id" => "#{child_concept_id}",
                         "resource_type" => "concept",
                         "rule_count" => 0,
                         "shared_to" => [],
                         "shared_to_ids" => [],
                         "tags" => []
                       }
                     ]
                   },
                   %{
                     "note" => nil,
                     "data_structure_id" => "#{nodef_child_ds_id}",
                     "id" => "#{nodef_child_dsv_id}",
                     "type" => "Table",
                     "profile" => nil,
                     "links" => []
                   }
                 ],
                 "user_permissions" => %{
                   "confidential" => true,
                   "create_foreign_grant_request" => true,
                   "profile_permission" => true,
                   "request_grant" => false,
                   "update" => true,
                   "update_domain" => true,
                   "update_grant_removal" => true,
                   "view_profiling_permission" => true
                 },
                 "relations" => %{
                   "children" => [
                     %{
                       "id" => "#{child_relation_id}",
                       "relation_type" => %{"name" => custom_relation_type_name},
                       "structure" => %{"id" => "#{nodef_child_dsv_id}"}
                     }
                   ],
                   "parents" => [
                     %{
                       "id" => "#{parent_relation_id}",
                       "relation_type" => %{"name" => custom_relation_type_name},
                       "structure" => %{"id" => "#{nodef_parent_dsv_id}"}
                     }
                   ]
                 }
               }
             } == data
    end

    @tag authentication: [role: "user"]
    test "returns forbidden for user without permission", %{conn: conn} do
      %{data_structure_id: data_structure_id} = insert(:data_structure_version)
      variables = %{"dataStructureId" => data_structure_id, "version" => "latest"}

      assert %{"data" => data, "errors" => errors} =
               conn
               |> post("/api/v2", %{
                 "query" => @version_query,
                 "variables" => variables
               })
               |> json_response(:ok)

      assert data == %{"dataStructureVersion" => nil}
      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "user", permissions: [:view_data_structure]]
    test "returns data when queried by user with permission", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{id: data_structure_id} = insert(:data_structure, domain_ids: [domain_id])
      %{id: id} = insert(:data_structure_version, data_structure_id: data_structure_id)
      variables = %{"dataStructureId" => data_structure_id, "version" => "latest"}

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @version_query,
                 "variables" => variables
               })
               |> json_response(:ok)

      string_id = "#{id}"
      assert response["errors"] == nil
      assert %{"dataStructureVersion" => %{"id" => ^string_id}} = data
    end

    @tag authentication: [role: "user", permissions: [:view_data_structure]]
    test "returns data childs when the childs have permissions by the user",
         %{
           conn: conn,
           domain: %{id: domain_id}
         } do
      %{id: domain_id_without_permissions} = CacheHelpers.insert_domain()

      %{id: ds_father_id} =
        structure_father =
        insert(:data_structure,
          external_id: "father",
          domain_ids: [domain_id, domain_id_without_permissions]
        )

      %{id: dsv_father_id} =
        insert(:data_structure_version, data_structure: structure_father, version: 1)

      structure_child_2_dom =
        insert(:data_structure,
          external_id: "child_2_dom",
          domain_ids: [domain_id, domain_id_without_permissions]
        )

      %{id: dsv_child_2_dom_id} =
        insert(:data_structure_version, data_structure: structure_child_2_dom, version: 1)

      structure_child_1_dom_with =
        insert(:data_structure,
          external_id: "ds_child_1_with_permissions",
          domain_ids: [domain_id]
        )

      %{id: dsv_child_1_with_permissions_id} =
        insert(:data_structure_version, data_structure: structure_child_1_dom_with, version: 1)

      structure_child_1_dom_without =
        insert(:data_structure,
          external_id: "ds_child_1_without_permissions",
          domain_ids: [domain_id_without_permissions]
        )

      %{id: dsv_child_1_without_permissions_id} =
        insert(:data_structure_version, data_structure: structure_child_1_dom_without, version: 1)

      ## Structure relations

      create_relation(dsv_father_id, dsv_child_2_dom_id)
      create_relation(dsv_father_id, dsv_child_1_with_permissions_id)
      create_relation(dsv_father_id, dsv_child_1_without_permissions_id)

      variables = %{"dataStructureId" => ds_father_id, "version" => "latest"}

      assert %{"data" => %{"dataStructureVersion" => %{"children" => children}} = data} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @permissions_domains_query,
                 "variables" => variables
               })
               |> json_response(:ok)

      assert [
               %{
                 "dataStructure" => %{
                   "domain_ids" => [^domain_id, ^domain_id_without_permissions],
                   "external_id" => "child_2_dom"
                 }
               },
               %{
                 "dataStructure" => %{
                   "domain_ids" => [^domain_id],
                   "external_id" => "ds_child_1_with_permissions"
                 }
               }
             ] = children

      string_id = "#{dsv_father_id}"
      assert response["errors"] == nil
      assert %{"dataStructureVersion" => %{"id" => ^string_id}} = data
    end

    @tag authentication: [role: "user", permissions: [:view_data_structure]]
    test "returns data siblings when the siblings have permissions by the user",
         %{
           conn: conn,
           domain: %{id: domain_id}
         } do
      %{id: domain_id_without_permissions} = CacheHelpers.insert_domain()

      structure_father =
        insert(:data_structure,
          external_id: "father",
          domain_ids: [domain_id, domain_id_without_permissions]
        )

      %{id: dsv_father_id} =
        insert(:data_structure_version, data_structure: structure_father, version: 1)

      %{id: structure_sibling_2_id} =
        structure_sibling_2_dom =
        insert(:data_structure,
          external_id: "child_2_dom",
          domain_ids: [domain_id, domain_id_without_permissions]
        )

      %{id: dsv_sibling_2_id} =
        insert(:data_structure_version, data_structure: structure_sibling_2_dom, version: 1)

      structure_sibling_1_dom_with =
        insert(:data_structure,
          external_id: "ds_sibling_1_with_permissions",
          domain_ids: [domain_id]
        )

      %{id: dsv_sibling_1_with_permissions_id} =
        insert(:data_structure_version, data_structure: structure_sibling_1_dom_with, version: 1)

      structure_sibling_1_dom_without =
        insert(:data_structure,
          external_id: "ds_sibling_1_without_permissions",
          domain_ids: [domain_id_without_permissions]
        )

      %{id: dsv_sibling_1_without_permissions_id} =
        insert(:data_structure_version,
          data_structure: structure_sibling_1_dom_without,
          version: 1
        )

      ## Structure relations

      create_relation(dsv_father_id, dsv_sibling_2_id)
      create_relation(dsv_father_id, dsv_sibling_1_with_permissions_id)
      create_relation(dsv_father_id, dsv_sibling_1_without_permissions_id)

      variables = %{"dataStructureId" => structure_sibling_2_id, "version" => "latest"}

      assert %{"data" => %{"dataStructureVersion" => %{"siblings" => siblings}} = data} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @permissions_domains_query,
                 "variables" => variables
               })
               |> json_response(:ok)

      assert [
               %{
                 "dataStructure" => %{
                   "domain_ids" => [^domain_id, ^domain_id_without_permissions],
                   "external_id" => "child_2_dom"
                 }
               },
               %{
                 "dataStructure" => %{
                   "domain_ids" => [^domain_id],
                   "external_id" => "ds_sibling_1_with_permissions"
                 }
               }
             ] = siblings

      string_id = "#{dsv_sibling_2_id}"
      assert response["errors"] == nil
      assert %{"dataStructureVersion" => %{"id" => ^string_id}} = data
      assert length(siblings) == 2
    end

    @tag authentication: [role: "admin"]
    test "returns data and domains herarchy", %{conn: conn} do
      %{id: father_domain_id} = father_domain = CacheHelpers.insert_domain()

      %{id: child_domain_id} =
        child_domain =
        CacheHelpers.insert_domain(parent_id: father_domain_id, parents: [father_domain])

      structure =
        insert(:data_structure,
          external_id: "structure",
          domain_ids: [child_domain_id],
          domains: [child_domain]
        )

      insert(:data_structure_version, data_structure: structure, version: 1)

      variables = %{"dataStructureId" => structure.id, "version" => "latest"}

      assert %{
               "data" => %{
                 "dataStructureVersion" => %{"dataStructure" => %{"domains" => domains}}
               }
             } =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @domains_herarchy_query,
                 "variables" => variables
               })
               |> json_response(:ok)

      str_child_id = to_string(child_domain_id)
      str_father_id = to_string(father_domain_id)

      assert [
               %{
                 "id" => ^str_child_id,
                 "parent_id" => ^str_father_id,
                 "parents" => [%{"id" => ^str_father_id}]
               }
             ] = domains

      assert response["errors"] == nil
    end

    @tag authentication: [role: "user", permissions: [:view_data_structure]]
    test "returns data childs with alias",
         %{
           conn: conn,
           domain: %{id: domain_id}
         } do
      %{id: ds_father_id} =
        structure_father = insert(:data_structure, external_id: "father", domain_ids: [domain_id])

      %{id: dsv_father_id} =
        insert(:data_structure_version, data_structure: structure_father, version: 1)

      structure_child_with_alias =
        insert(:data_structure, alias: "alias_structure", domain_ids: [domain_id])

      %{id: dsv_child_with_alias_id} =
        insert(:data_structure_version,
          data_structure: structure_child_with_alias,
          version: 1,
          class: "field"
        )

      structure_child_without_alias = insert(:data_structure, domain_ids: [domain_id])

      %{id: dsv_child_without_alias_id} =
        insert(:data_structure_version,
          data_structure: structure_child_without_alias,
          version: 1,
          class: "field"
        )

      ## Structure relations

      create_relation(dsv_father_id, dsv_child_with_alias_id)
      create_relation(dsv_father_id, dsv_child_without_alias_id)

      dsv_children_without_alias_id = to_string(dsv_child_without_alias_id)
      dsv_children_with_alias_id = to_string(dsv_child_with_alias_id)

      children_without_alias_id = to_string(structure_child_without_alias.id)
      children_with_alias_id = to_string(structure_child_with_alias.id)

      variables = %{"dataStructureId" => ds_father_id, "version" => "latest"}

      assert %{
               "data" => %{
                 "dataStructureVersion" => %{"children" => children, "data_fields" => data_fields}
               }
             } =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @alias_children_query,
                 "variables" => variables
               })
               |> json_response(:ok)

      assert response["errors"] == nil

      assert [
               %{
                 "id" => ^dsv_children_with_alias_id,
                 "alias" => "alias_structure"
               },
               %{
                 "id" => ^dsv_children_without_alias_id,
                 "alias" => nil
               }
             ] = children

      assert [
               %{
                 "alias" => "alias_structure",
                 "data_structure_id" => ^children_with_alias_id
               },
               %{
                 "alias" => nil,
                 "data_structure_id" => ^children_without_alias_id
               }
             ] = data_fields
    end

    @tag authentication: [role: "user", permissions: [:view_data_structure]]
    test "returns data siblings with alias",
         %{
           conn: conn,
           domain: %{id: domain_id}
         } do
      structure_father = insert(:data_structure, external_id: "father", domain_ids: [domain_id])

      %{id: dsv_father_id} =
        insert(:data_structure_version, data_structure: structure_father, version: 1)

      structure_sibling_with_alias =
        insert(:data_structure, alias: "alias_structure", domain_ids: [domain_id])

      %{id: dsv_sibling_with_alias_id} =
        insert(:data_structure_version, data_structure: structure_sibling_with_alias, version: 1)

      %{id: structure_sibling_without_alias_id} =
        structure_sibling_without_alias = insert(:data_structure, domain_ids: [domain_id])

      %{id: dsv_sibling_without_alias_id} =
        insert(:data_structure_version,
          data_structure: structure_sibling_without_alias,
          version: 1
        )

      ## Structure relations

      create_relation(dsv_father_id, dsv_sibling_with_alias_id)
      create_relation(dsv_father_id, dsv_sibling_without_alias_id)

      sibling_without_alias_id = to_string(dsv_sibling_without_alias_id)
      sibling_with_alias_id = to_string(dsv_sibling_with_alias_id)

      variables = %{
        "dataStructureId" => structure_sibling_without_alias_id,
        "version" => "latest"
      }

      assert %{"data" => %{"dataStructureVersion" => %{"siblings" => siblings}}} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @alias_siblings_query,
                 "variables" => variables
               })
               |> json_response(:ok)

      assert response["errors"] == nil

      assert [
               %{
                 "id" => ^sibling_with_alias_id,
                 "alias" => "alias_structure"
               },
               %{
                 "id" => ^sibling_without_alias_id,
                 "alias" => nil
               }
             ] = siblings
    end
  end

  describe "dataStructureRelations query" do
    @tag authentication: [role: "user"]
    test "returns forbidden when queried by user role", %{conn: conn} do
      assert %{"data" => data, "errors" => errors} =
               conn
               |> post("/api/v2", %{"query" => @relations_query, "variables" => @variables})
               |> json_response(:ok)

      assert data == %{"dataStructureRelations" => nil}
      assert [%{"message" => "forbidden"}] = errors
    end

    @tag authentication: [role: "service"]
    test "returns data when queried by service role", %{conn: conn} do
      %{id: expected_id, relation_type: %{name: type_name}} = insert(:data_structure_relation)

      variables = Map.put(@variables, "types", [type_name])

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{"query" => @relations_query, "variables" => variables})
               |> json_response(:ok)

      assert response["errors"] == nil
      assert %{"dataStructureRelations" => data_structure_relations} = data

      assert [
               %{
                 "id" => id,
                 "parent" => %{"id" => _},
                 "child" => %{"id" => _},
                 "relationType" => %{"id" => _}
               }
             ] = data_structure_relations

      assert id == to_string(expected_id)
    end
  end

  defp create_relation(parent_id, child_id) do
    create_relation(parent_id, child_id, RelationTypes.default_id!())
  end

  defp create_relation(parent_id, child_id, relation_type_id) do
    insert(:data_structure_relation,
      parent_id: parent_id,
      child_id: child_id,
      relation_type_id: relation_type_id
    )
  end
end
