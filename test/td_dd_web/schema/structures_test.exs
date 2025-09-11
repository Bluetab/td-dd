defmodule TdDdWeb.Schema.StructuresTest do
  use TdDdWeb.ConnCase
  use TdDd.GraphDataCase

  alias TdDd.DataStructures.Hierarchy
  alias TdDd.DataStructures.RelationTypes
  alias TdDd.Lineage.GraphData
  alias TdDd.Lineage.GraphData.State

  require Logger

  @moduletag sandbox: :shared

  @protected "_protected"

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

  @metric_versions_query """
    query dataStructureVersions($limit: Int!, $since: DateTime, $minId: Int) {
      dataStructureVersions(limit: $limit, since: $since, minId: $minId) {
          id
          description
          version
          metadata
          name
          dataStructure {
              id
              domainId
              domainIds
              externalId
              system {
                  id
                  externalId
              }
          }
          insertedAt
          updatedAt
          deletedAt
          class
          type
          group
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
      parents {
        dataStructure { external_id }
        classes
      }
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
      has_note
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
        has_note
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

  @enriched_data_fields_query """
  query DataStructureVersion($dataStructureId: ID!, $version: String!){
    dataStructureVersion(dataStructureId: $dataStructureId, version: $version) {
      dataFields {
        name
        degree {
          in
          out
        }
      }
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

  @siblings_query """
  query DataStructureVersion($dataStructureId: ID!, $version: String!, $siblings_limit: Int) {
    dataStructureVersion(dataStructureId: $dataStructureId, version: $version) {
      id
      siblings(limit: $siblings_limit) {
        id
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

  @version_data_fields_query """
  query DataStructureVersion($dataStructureId: ID!, $version: String!, $data_fields_limit: Int) {
    dataStructureVersion(dataStructureId: $dataStructureId, version: $version) {
      id
      dataFields(first: $data_fields_limit) {
        id
        name
      }
    }
  }
  """

  @data_fields_query """
  query DataFields($dataStructureId: ID!, $version: String!, $first: Int, $last: Int, $before: Cursor, $after: Cursor, $search: String, $filters: DataFieldsFilter) {
    dataFields(dataStructureId: $dataStructureId, version: $version, first: $first, last: $last, before: $before, after: $after, search: $search, filters: $filters) {
      page {
        id
        name
        has_note
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
        degree {
            in
            out
        }
      }
      pageInfo {
        startCursor
        endCursor
        hasNextPage
        hasPreviousPage
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

  @metadata_query """
  query DataStructureVersion($dataStructureId: ID!, $version: String!) {
    dataStructureVersion(dataStructureId: $dataStructureId, version: $version) {
      id
      metadata
      children {
        id
        metadata
      }
      data_fields {
        id
        metadata
      }
      parents {
        id
        metadata
      }
    }
  }
  """

  @profile_query """
  query DataStructureVersion($dataStructureId: ID!, $version: String!) {
    dataStructureVersion(dataStructureId: $dataStructureId, version: $version) {
      id
      profile {
        max
        min
        null_count
        most_frequent
        value
      }
    }
  }
  """

  @note_query """
  query DataStructureVersion($dataStructureId: ID!, $version: String!) {
    dataStructureVersion(dataStructureId: $dataStructureId, version: $version) {
      id
      parents{
        id
        has_note
        note
      }
      children{
        id
        has_note
        note
      }
      data_fields {
        id
        has_note
        note
      }
      has_note
      note
    }
  }
  """
  @variables %{"since" => "2020-01-01T00:00:00Z"}
  @metadata %{"foo" => %{"value" => ["bar"], "origin" => "user"}}

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
      %{parent_id: parent_id} =
        insert(:data_structure_relation, relation_type_id: RelationTypes.default_id!())

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
    test "returns only children with default relation type", %{conn: conn} do
      %{id: ds_father_id} =
        structure_father =
        insert(:data_structure,
          external_id: "father"
        )

      %{id: dsv_father_id} =
        insert(:data_structure_version, data_structure: structure_father, version: 1)

      structure_child_1_dom =
        insert(:data_structure,
          external_id: "child_1_dom"
        )

      %{id: dsv_child_1_dom_id} =
        insert(:data_structure_version, data_structure: structure_child_1_dom, version: 1)

      structure_child_2_dom =
        insert(:data_structure,
          external_id: "child_2_dom"
        )

      %{id: dsv_child_2_dom_id} =
        insert(:data_structure_version, data_structure: structure_child_2_dom, version: 1)

      %{id: non_default_relation_type_id} = insert(:relation_type)

      ## Structure relations

      create_relation(dsv_father_id, dsv_child_1_dom_id)
      create_relation(dsv_father_id, dsv_child_2_dom_id, non_default_relation_type_id)

      variables = %{"dataStructureId" => ds_father_id, "version" => "latest"}

      assert %{"data" => %{"dataStructureVersion" => %{"children" => children}}} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @version_query,
                 "variables" => variables
               })
               |> json_response(:ok)

      assert response["errors"] == nil

      assert [
               %{
                 "dataStructure" => %{
                   "external_id" => "child_1_dom"
                 }
               }
             ] = children
    end

    @tag authentication: [role: "service"]
    test "returns previous version", %{conn: conn} do
      data_structure = insert(:data_structure)

      data_structure_version =
        insert(:data_structure_version, data_structure: data_structure, version: 0)

      insert(:data_structure_version, data_structure: data_structure, version: 1)

      variables = %{"dataStructureId" => data_structure.id, "version" => "0"}

      assert %{"data" => %{"dataStructureVersion" => %{"id" => id, "version" => version}}} =
               conn
               |> post("/api/v2", %{
                 "query" => @version_query,
                 "variables" => variables
               })
               |> json_response(:ok)

      assert String.to_integer(id) == data_structure_version.id
      assert version == data_structure_version.version
    end

    @tag authentication: [role: "service"]
    test "data fields enriched with degree", %{conn: conn} do
      %{id: ds_father_id} =
        structure_father =
        insert(:data_structure,
          external_id: "table"
        )

      %{id: dsv_father_id} =
        insert(:data_structure_version,
          data_structure: structure_father,
          version: 1,
          class: "table",
          name: "table"
        )

      structure_child_1 =
        insert(:data_structure,
          external_id: "field_1"
        )

      %{id: dsv_child_1_id} =
        insert(:data_structure_version,
          data_structure: structure_child_1,
          version: 1,
          class: "field",
          name: "field_1"
        )

      structure_child_2 =
        insert(:data_structure,
          external_id: "field_2"
        )

      %{id: dsv_child_2_id} =
        insert(:data_structure_version,
          data_structure: structure_child_2,
          version: 1,
          class: "field",
          name: "field_2"
        )

      ## Structure relations

      create_relation(dsv_father_id, dsv_child_1_id)
      create_relation(dsv_father_id, dsv_child_2_id)

      ### Graph

      nodes = ["table", "field_1", "field_2"]

      GraphData.state(
        state:
          setup_state(%{
            contains: nodes,
            depends: [
              {"table", "field_1", [metadata: "table_to_field_label"]},
              {"table", "field_2", [metadata: "table_to_field_label"]},
              {"field_1", "field_2", [metadata: "field_to_field_label"]}
            ]
          })
      )

      variables = %{"dataStructureId" => ds_father_id, "version" => "latest"}

      assert %{"data" => %{"dataStructureVersion" => %{"dataFields" => data_fields}}} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @enriched_data_fields_query,
                 "variables" => variables
               })
               |> json_response(:ok)

      assert response["errors"] == nil

      assert [
               %{"degree" => %{"in" => 1, "out" => 1}, "name" => "field_1"},
               %{"degree" => %{"in" => 2, "out" => 0}, "name" => "field_2"}
             ] = data_fields
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

      %{class: class_value_parent, name: class_name_parent} =
        insert(:structure_classification, data_structure_version_id: parent_dsv_id)

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
        df_content: %{"foo" => %{"value" => "bar", "origin" => "user"}},
        status: :published
      )

      insert(:structure_note,
        data_structure_id: child_ds_id,
        df_content: %{
          "foo" => %{"value" => "bar", "origin" => "user"},
          "child_field" => %{"value" => "value1", "origin" => "user"},
          "not_selected_field" => %{"value" => "value2", "origin" => "user"}
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
      concept_name_es = "concept_name_es"

      %{id: concept_id} =
        CacheHelpers.insert_concept(%{
          name: "concept_name_en",
          content: %{},
          i18n: %{
            "es" => %{
              "name" => concept_name_es,
              "content" => %{}
            }
          }
        })

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
          child_concept_id,
          ["my_link_tag"],
          "test_origin"
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
               |> put_req_header("accept-language", "es")
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
                   },
                   "manage_structure_acl_entry" => %{}
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
                 "metadata" => %{
                   "description" => "some description"
                 },
                 "parents" => [
                   %{
                     "dataStructure" => %{"external_id" => "parent"},
                     "classes" => %{class_name_parent => class_value_parent}
                   }
                 ],
                 "children" => [
                   %{
                     "dataStructure" => %{"external_id" => "child"},
                     "classes" => %{class_name_child => class_value_child}
                   }
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
                 "has_note" => true,
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
                     "name" => "#{concept_name_es}",
                     "resource_id" => "#{concept_id}",
                     "resource_type" => "concept",
                     "rule_count" => 0,
                     "shared_to" => [],
                     "shared_to_ids" => [],
                     "tags" => [],
                     "origin" => nil,
                     "i18n" => "{\"es\":{\"content\":{},\"name\":\"#{concept_name_es}\"}}"
                   }
                 ],
                 "grant" => %{"id" => "#{grant_id}"},
                 "grants" => [%{"id" => "#{grant_id}"}],
                 "data_fields" => [
                   %{
                     "has_note" => true,
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
                         "link_tags" => ["my_link_tag"],
                         "name" => "#{child_concept_name}",
                         "resource_id" => "#{child_concept_id}",
                         "resource_type" => "concept",
                         "rule_count" => 0,
                         "shared_to" => [],
                         "shared_to_ids" => [],
                         "tags" => ["my_link_tag"],
                         "origin" => "test_origin"
                       }
                     ]
                   },
                   %{
                     "has_note" => false,
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
                   "view_profiling_permission" => true,
                   "view_quality" => true
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

    @tag authentication: [role: "service"]
    test "returns data when queried from metrics connector", %{
      conn: conn
    } do
      dsv1_day = ~U[2019-04-16 00:00:00Z]
      dsv1_ds_day = ~U[2023-05-22 00:00:00Z]
      dsv2_day = ~U[2019-06-17 00:00:00Z]
      dsv2_deleted_day = ~U[2023-04-28 00:00:00Z]
      dsv2_ds_day = ~U[2022-10-25 00:00:00Z]
      since = "2022-11-22 00:00:00Z"

      ds1 = insert(:data_structure, inserted_at: dsv1_ds_day, updated_at: dsv1_ds_day)
      ds2 = insert(:data_structure, inserted_at: dsv2_ds_day, updated_at: dsv2_ds_day)

      dsv1 =
        insert(:data_structure_version,
          data_structure_id: ds1.id,
          version: 0,
          inserted_at: dsv1_day,
          updated_at: dsv1_day
        )

      dsv2 =
        insert(:data_structure_version,
          data_structure_id: ds2.id,
          version: 0,
          inserted_at: dsv2_day,
          updated_at: dsv2_day,
          deleted_at: dsv2_deleted_day
        )

      string_dsv2_id = to_string(dsv2.id)

      variables = %{limit: 2, since: since, minId: dsv1.id + 1}

      assert %{"data" => data} =
               response =
               conn
               |> post("/api/v2", %{
                 "query" => @metric_versions_query,
                 "variables" => variables
               })
               |> json_response(:ok)

      assert response["errors"] == nil

      assert %{
               "dataStructureVersions" => [
                 %{"id" => ^string_dsv2_id}
               ]
             } = data
    end

    @tag authentication: [role: "user", permissions: [:view_data_structure]]
    test "returns data children when the children have permissions by the user",
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
    test "returns siblings", %{conn: conn, domain: %{id: domain_id}} do
      %{id: parent_id} =
        insert(:data_structure_version,
          data_structure: build(:data_structure, domain_ids: [domain_id])
        )

      %{id: id, data_structure_id: data_structure_id} =
        insert(:data_structure_version,
          data_structure: build(:data_structure, domain_ids: [domain_id])
        )

      %{id: sibling_id} =
        insert(:data_structure_version,
          data_structure: build(:data_structure, domain_ids: [domain_id])
        )

      relation_type_id = RelationTypes.default_id!()

      insert(:data_structure_relation,
        parent_id: parent_id,
        child_id: id,
        relation_type_id: relation_type_id
      )

      insert(:data_structure_relation,
        parent_id: parent_id,
        child_id: sibling_id,
        relation_type_id: relation_type_id
      )

      variables = %{"dataStructureId" => data_structure_id, "version" => "latest"}

      %{"data" => %{"dataStructureVersion" => %{"siblings" => siblings}}} =
        conn
        |> post("/api/v2", %{
          "query" => @siblings_query,
          "variables" => variables
        })
        |> json_response(:ok)

      assert Enum.count(siblings) == 2
      assert Enum.find(siblings, &(&1["id"] == Integer.to_string(id)))
      assert Enum.find(siblings, &(&1["id"] == Integer.to_string(sibling_id)))

      variables = %{
        "dataStructureId" => data_structure_id,
        "version" => "latest",
        "siblings_limit" => 1
      }

      %{"data" => %{"dataStructureVersion" => %{"siblings" => siblings}}} =
        conn
        |> post("/api/v2", %{
          "query" => @siblings_query,
          "variables" => variables
        })
        |> json_response(:ok)

      assert Enum.count(siblings) == 1
    end

    @tag authentication: [role: "service"]
    test "returns version data fields", %{conn: conn} do
      %{id: dsv_father_id, data_structure_id: data_structure_id} =
        insert(:data_structure_version, version: 1, class: "table", name: "table")

      %{id: dsv_child_1_id} =
        insert(:data_structure_version, version: 1, class: "field", name: "field_1")

      %{id: dsv_child_2_id} =
        insert(:data_structure_version, version: 1, class: "field", name: "field_2")

      ## Structure relations
      create_relation(dsv_father_id, dsv_child_1_id)
      create_relation(dsv_father_id, dsv_child_2_id)

      variables = %{"dataStructureId" => data_structure_id, "version" => "latest"}

      %{"data" => %{"dataStructureVersion" => %{"dataFields" => data_fields}}} =
        conn
        |> post("/api/v2", %{
          "query" => @version_data_fields_query,
          "variables" => variables
        })
        |> json_response(:ok)

      assert Enum.count(data_fields) == 2
      assert Enum.find(data_fields, &(&1["id"] == Integer.to_string(dsv_child_1_id)))
      assert Enum.find(data_fields, &(&1["id"] == Integer.to_string(dsv_child_2_id)))

      variables = %{
        "dataStructureId" => data_structure_id,
        "version" => "latest",
        "data_fields_limit" => 1
      }

      %{"data" => %{"dataStructureVersion" => %{"dataFields" => data_fields}}} =
        conn
        |> post("/api/v2", %{
          "query" => @version_data_fields_query,
          "variables" => variables
        })
        |> json_response(:ok)

      assert Enum.count(data_fields) == 1
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

    @tag authentication: [
           role: "user",
           permissions: [:view_data_structure, :view_protected_metadata]
         ]
    test "returns metadata for children", %{conn: conn, domain: %{id: domain_id}} do
      # main
      %{id: ds_main_id} =
        structure_main = insert(:data_structure, external_id: "main", domain_ids: [domain_id])

      %{id: dsv_main_id} =
        insert(:data_structure_version,
          data_structure: structure_main,
          version: 1,
          metadata: %{"foo_main" => "this is no mutable (main)"}
        )

      mutable_metadata_main = %{
        "mm_foo_main" => "this is mutable (main)",
        @protected => %{"mm_protected_main" => "this is protected mutable (main)"}
      }

      insert(:structure_metadata,
        data_structure_id: ds_main_id,
        fields: mutable_metadata_main
      )

      # child 1
      structure_child_1 = insert(:data_structure, external_id: "child_1", domain_ids: [domain_id])

      %{id: dsv_child_1} =
        insert(:data_structure_version,
          data_structure: structure_child_1,
          version: 1,
          class: "field",
          metadata: %{"foo_child" => "this is no mutable (child)"}
        )

      mutable_metadata_1 = %{
        "mm_foo" => "this is mutable (child)",
        @protected => %{"mm_protected" => "this is protected mutable (child)"}
      }

      insert(:structure_metadata,
        data_structure_id: structure_child_1.id,
        fields: mutable_metadata_1
      )

      create_relation(dsv_main_id, dsv_child_1)

      # parent
      structure_parent_1 =
        insert(:data_structure, external_id: "parent_1", domain_ids: [domain_id])

      %{id: dsv_parent_1} =
        insert(:data_structure_version,
          data_structure: structure_parent_1,
          version: 1,
          class: "field",
          metadata: %{"foo_parent" => "this is no mutable (parent)"}
        )

      mutable_metadata_1 = %{
        "mm_foo" => "this is mutable (parent)",
        @protected => %{"mm_protected" => "this is protected mutable (parent)"}
      }

      insert(:structure_metadata,
        data_structure_id: structure_parent_1.id,
        fields: mutable_metadata_1
      )

      create_relation(dsv_parent_1, dsv_main_id)

      variables = %{"dataStructureId" => ds_main_id, "version" => "latest"}
      # assert main
      str_dsv_main = to_string(dsv_main_id)

      metadata_main = %{
        "_protected" => %{"mm_protected_main" => "this is protected mutable (main)"},
        "foo_main" => "this is no mutable (main)",
        "mm_foo_main" => "this is mutable (main)"
      }

      assert %{
               "data" => %{
                 "dataStructureVersion" => %{
                   "id" => ^str_dsv_main,
                   "metadata" => ^metadata_main,
                   "parents" => parents,
                   "children" => children,
                   "data_fields" => data_fields
                 }
               }
             } =
               conn
               |> post("/api/v2", %{
                 "query" => @metadata_query,
                 "variables" => variables
               })
               |> json_response(:ok)

      # assert children
      str_dsv_child_1 = to_string(dsv_child_1)

      metadata_child = %{
        "_protected" => %{"mm_protected" => "this is protected mutable (child)"},
        "foo_child" => "this is no mutable (child)",
        "mm_foo" => "this is mutable (child)"
      }

      assert [
               %{
                 "id" => ^str_dsv_child_1,
                 "metadata" => ^metadata_child
               }
             ] = children

      assert [%{"id" => ^str_dsv_child_1, "metadata" => ^metadata_child}] = data_fields

      # assert parent
      str_dsv_parent_1 = to_string(dsv_parent_1)

      metadata_parent = %{
        "_protected" => %{"mm_protected" => "this is protected mutable (parent)"},
        "foo_parent" => "this is no mutable (parent)",
        "mm_foo" => "this is mutable (parent)"
      }

      assert [
               %{
                 "id" => ^str_dsv_parent_1,
                 "metadata" => ^metadata_parent
               }
             ] = parents
    end

    defp insert_family_of_structures(
           number_of_children,
           number_of_versions,
           metadata_duplications
         ) do
      %{id: domain_id} = CacheHelpers.insert_domain()

      %{id: ds_main_id} = structure_main = insert(:data_structure, domain_ids: [domain_id])

      %{id: dsv_main_id} =
        insert(:data_structure_version,
          data_structure: structure_main,
          version: 1,
          metadata: %{"foo_main" => "this is no mutable (main)"}
        )

      mutable_metadata_main = %{
        "mm_foo_main" => "this is mutable (main)",
        @protected => %{"mm_protected_main" => "this is protected mutable (main)"}
      }

      insert(:structure_metadata,
        data_structure_id: ds_main_id,
        fields: mutable_metadata_main
      )

      for n_child <- 1..number_of_children do
        structure_child = insert(:data_structure, domain_ids: [domain_id])

        %{id: dsv_child} =
          insert(:data_structure_version,
            data_structure: structure_child,
            version: 1,
            class: "field",
            metadata: %{"foo_child" => "this is no mutable (child #{n_child})"}
          )

        for version <- 1..number_of_versions do
          insert(:structure_metadata,
            data_structure_id: structure_child.id,
            version: version,
            fields: %{
              "mm_foo" =>
                String.duplicate(
                  "this is mutable (child #{n_child}) with version #{version}",
                  metadata_duplications
                ),
              @protected => %{
                "mm_protected" =>
                  "this is protected mutable (child #{n_child}) with version #{version}"
              }
            }
          )
        end

        create_relation(dsv_main_id, dsv_child)
      end

      # parent
      structure_parent_1 = insert(:data_structure, domain_ids: [domain_id])

      %{id: dsv_parent_1} =
        insert(:data_structure_version,
          data_structure: structure_parent_1,
          version: 1,
          class: "field",
          metadata: %{"foo_parent" => "this is no mutable (parent)"}
        )

      mutable_metadata_1 = %{
        "mm_foo" => "this is mutable (parent)",
        @protected => %{"mm_protected" => "this is protected mutable (parent)"}
      }

      insert(:structure_metadata,
        data_structure_id: structure_parent_1.id,
        fields: mutable_metadata_1
      )

      create_relation(dsv_parent_1, dsv_main_id)
      ds_main_id
    end

    @tag authentication: [role: "admin"]
    test "count accesses to database when retrieve metadata for children", %{conn: conn} do
      number_of_children = 20
      ds_main_id = insert_family_of_structures(number_of_children, 20, 2000)
      query_variables = %{"dataStructureId" => ds_main_id, "version" => "latest"}

      QueryCounter.start()

      :telemetry.attach(
        "ecto-query-count",
        [:td_dd, :repo, :query],
        &QueryCounter.count/4,
        %{}
      )

      query_children = """
      query DataStructureVersion($dataStructureId: ID!, $version: String!) {
        dataStructureVersion(dataStructureId: $dataStructureId, version: $version) {
          id,
          children {
            id,
            data_structure {
              id
            }
          }
        }
      }
      """

      query_children_metadata = """
      query DataStructureVersion($dataStructureId: ID!, $version: String!) {
        dataStructureVersion(dataStructureId: $dataStructureId, version: $version) {
          id,
          children {
            id,
            metadata
          }
        }
      }
      """

      assert conn
             |> post("/api/v2", %{
               "query" => query_children,
               "variables" => query_variables
             })
             |> json_response(:ok)

      query_count = QueryCounter.total()

      QueryCounter.stop()
      QueryCounter.start()

      initial_memory = :erlang.memory(:total)

      assert conn
             |> post("/api/v2", %{
               "query" => query_children_metadata,
               "variables" => query_variables
             })
             |> json_response(:ok)

      :telemetry.detach("ecto-query-count")
      final_memory = :erlang.memory(:total)
      # megabytes
      memory_consumed = (final_memory - initial_memory) / 1_000_000
      expected_memory_consumption = 1
      expected_memory_tolerance = 10
      memory_consumption_limit = expected_memory_consumption * expected_memory_tolerance

      if memory_consumed > memory_consumption_limit do
        Logger.warning(
          "\n High memory consumed: #{memory_consumed} Mbytes \n Consider to review in memory operations"
        )
      end

      metadata_query_count = QueryCounter.total()
      QueryCounter.stop()

      delta_count = metadata_query_count - query_count
      assert 1 == delta_count
    end

    @tag authentication: [
           role: "user",
           permissions: [:view_data_structure]
         ]
    test "get data without profile permission", %{conn: conn, domain: %{id: domain_id}} do
      %{id: ds_id} = structure = insert(:data_structure, domain_ids: [domain_id])

      insert(:profile,
        data_structure_id: ds_id,
        min: "3",
        max: "5",
        null_count: 0,
        most_frequent: ~s([["A", "22"]])
      )

      %{id: dsv_id} =
        insert(:data_structure_version,
          data_structure: structure,
          version: 1
        )

      variables = %{"dataStructureId" => ds_id, "version" => "latest"}

      %{"data" => data} =
        conn
        |> post("/api/v2", %{
          "query" => @profile_query,
          "variables" => variables
        })
        |> json_response(:ok)

      str_dsv_id = to_string(dsv_id)

      assert %{
               "dataStructureVersion" => %{
                 "id" => ^str_dsv_id,
                 "profile" => nil
               }
             } = data
    end

    @tag authentication: [
           role: "user",
           permissions: [:view_data_structure]
         ]
    test "get data and data_fields with respective last note", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      # main
      %{id: id_ds_main_id} =
        structure_main = insert(:data_structure, external_id: "main", domain_ids: [domain_id])

      %{id: dsv_main_id} =
        insert(:data_structure_version,
          data_structure: structure_main,
          version: 1
        )

      insert(:structure_note,
        data_structure_id: id_ds_main_id,
        df_content: %{"foo main" => %{"value" => "bar main", "origin" => "user"}},
        status: :published
      )

      # child 1
      structure_child_1 = insert(:data_structure, external_id: "child_1", domain_ids: [domain_id])

      %{id: id_dsv_child_1} =
        insert(:data_structure_version,
          data_structure: structure_child_1,
          version: 1,
          class: "field"
        )

      create_relation(dsv_main_id, id_dsv_child_1)

      # child 2
      %{id: id_ds_child_2} =
        structure_child_2 =
        insert(:data_structure, external_id: "child_2", domain_ids: [domain_id])

      %{id: id_dsv_child_2} =
        insert(:data_structure_version,
          data_structure: structure_child_2,
          version: 1,
          class: "field"
        )

      insert(:structure_note,
        data_structure_id: id_ds_child_2,
        df_content: %{
          "foo" => %{"value" => "bar", "origin" => "user"},
          "child_field" => %{"value" => "value1", "origin" => "user"},
          "not_selected_field" => %{"value" => "value2", "origin" => "user"}
        },
        status: :published
      )

      create_relation(dsv_main_id, id_dsv_child_2)

      # parent
      %{id: id_ds_parent} =
        structure_parent = insert(:data_structure, external_id: "parent", domain_ids: [domain_id])

      %{id: id_dsv_parent} =
        insert(:data_structure_version,
          data_structure: structure_parent,
          version: 1,
          class: "field"
        )

      insert(:structure_note,
        data_structure_id: id_ds_parent,
        df_content: %{
          "foo" => %{"value" => "bar", "origin" => "user"},
          "parent_field" => %{"value" => "value1", "origin" => "user"},
          "not_selected_field" => %{"value" => "value2", "origin" => "user"}
        },
        status: :published
      )

      create_relation(id_dsv_parent, dsv_main_id)

      variables = %{"dataStructureId" => id_ds_main_id, "version" => "latest"}
      # assert main
      str_dsv_main = to_string(dsv_main_id)

      data_fields = [
        %{"note" => nil},
        %{
          "note" => %{
            "child_field" => "value1",
            "foo" => "bar",
            "not_selected_field" => "value2"
          }
        }
      ]

      parent_notes = [
        %{
          "note" => %{
            "parent_field" => "value1",
            "foo" => "bar",
            "not_selected_field" => "value2"
          }
        }
      ]

      children_notes = [
        %{"note" => nil},
        %{
          "note" => %{
            "child_field" => "value1",
            "foo" => "bar",
            "not_selected_field" => "value2"
          }
        }
      ]

      assert %{
               "data" => %{
                 "dataStructureVersion" => %{
                   "id" => ^str_dsv_main,
                   "has_note" => true,
                   "note" => %{"foo main" => "bar main"},
                   "parents" => response_parent,
                   "children" => response_children,
                   "data_fields" => response_data_fields
                 }
               }
             } =
               conn
               |> post("/api/v2", %{
                 "query" => @note_query,
                 "variables" => variables
               })
               |> json_response(:ok)

      assert data_fields ==
               Enum.map(response_data_fields, fn %{"note" => note} -> %{"note" => note} end)

      assert parent_notes ==
               Enum.map(response_parent, fn %{"note" => note} -> %{"note" => note} end)

      assert children_notes ==
               Enum.map(response_children, fn %{"note" => note} -> %{"note" => note} end)
    end

    @tag authentication: [
           role: "user",
           permissions: [:view_data_structure, :view_data_structures_profile]
         ]
    test "get data with profile permission", %{conn: conn, domain: %{id: domain_id}} do
      %{id: ds_id} = structure = insert(:data_structure, domain_ids: [domain_id])

      insert(:profile,
        data_structure_id: ds_id,
        min: "3",
        max: "5",
        null_count: 0,
        most_frequent: ~s([["A", "22"]])
      )

      %{id: dsv_id} =
        insert(:data_structure_version,
          data_structure: structure,
          version: 1
        )

      variables = %{"dataStructureId" => ds_id, "version" => "latest"}

      %{"data" => data} =
        conn
        |> post("/api/v2", %{
          "query" => @profile_query,
          "variables" => variables
        })
        |> json_response(:ok)

      str_dsv_id = to_string(dsv_id)

      assert %{
               "dataStructureVersion" => %{
                 "id" => ^str_dsv_id,
                 "profile" => %{
                   "max" => "5",
                   "min" => "3",
                   "most_frequent" => [%{"k" => "A", "v" => 22}],
                   "null_count" => 0
                 }
               }
             } = data
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
                 "dataStructureVersion" => %{
                   "children" => children,
                   "data_fields" => data_fields
                 }
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

  describe "dataFields query" do
    @tag authentication: [role: "service"]
    test "returns data fields for latest data structure version", %{conn: conn} do
      %{id: dsv_father_id, data_structure_id: data_structure_id} =
        insert(:data_structure_version, version: 1, class: "table", name: "table")

      %{id: dsv_child_1_id, data_structure: child_data_structure} =
        insert(:data_structure_version, version: 1, class: "field", name: "field_1")

      %{id: dsv_child_2_id} =
        insert(:data_structure_version, version: 1, class: "field", name: "field_2")

      ## Structure relations
      create_relation(dsv_father_id, dsv_child_1_id)
      create_relation(dsv_father_id, dsv_child_2_id)

      ## Structure Note
      insert(:structure_note,
        data_structure_id: child_data_structure.id,
        df_content: %{"foo" => %{"value" => "bar", "origin" => "user"}},
        status: :published
      )

      ## Structure Profile
      insert(:profile,
        data_structure_id: child_data_structure.id,
        min: "1",
        max: "2",
        null_count: 5,
        most_frequent: ~s([["A", "76"]])
      )

      ## Concepts relations
      %{id: concept_id} = CacheHelpers.insert_concept(%{name: "concept_name"})

      CacheHelpers.insert_link(
        child_data_structure.id,
        "data_structure",
        "business_concept",
        concept_id
      )

      ### Graph
      contains = %{"foo" => [child_data_structure.external_id, "baz"]}
      depends = [{child_data_structure.external_id, "baz"}]
      GraphData.state(state: setup_state(%{contains: contains, depends: depends}))

      variables = %{"dataStructureId" => data_structure_id, "version" => "latest"}

      %{"data" => %{"dataFields" => %{"page" => data_fields, "pageInfo" => page_info}}} =
        conn
        |> post("/api/v2", %{
          "query" => @data_fields_query,
          "variables" => variables
        })
        |> json_response(:ok)

      assert Enum.count(data_fields) == 2
      assert child = Enum.find(data_fields, &(&1["id"] == Integer.to_string(dsv_child_1_id)))
      assert child["degree"] == %{"in" => 0, "out" => 1}
      assert child["has_note"]

      assert child["profile"] == %{
               "max" => "2",
               "min" => "1",
               "most_frequent" => [%{"k" => "A", "v" => 76}],
               "null_count" => 5
             }

      assert [link] = child["links"]
      assert link["name"] == "concept_name"
      assert Enum.find(data_fields, &(&1["id"] == Integer.to_string(dsv_child_2_id)))

      assert page_info["endCursor"]
      assert page_info["startCursor"]
      refute page_info["hasNextPage"]
      refute page_info["hasPreviousPage"]

      variables = %{"dataStructureId" => data_structure_id, "version" => "latest", "first" => 1}

      %{"data" => %{"dataFields" => %{"page" => data_fields, "pageInfo" => page_info}}} =
        conn
        |> post("/api/v2", %{
          "query" => @data_fields_query,
          "variables" => variables
        })
        |> json_response(:ok)

      assert Enum.count(data_fields) == 1

      assert page_info["endCursor"]
      assert page_info["startCursor"]
      assert page_info["hasNextPage"]
      refute page_info["hasPreviousPage"]
    end

    @tag authentication: [role: "service"]
    test "returns empty list if data structure version doesn't exist", %{conn: conn} do
      variables = %{"dataStructureId" => 0, "version" => "latest"}

      %{"data" => %{"dataFields" => %{"page" => data_fields, "pageInfo" => page_info}}} =
        conn
        |> post("/api/v2", %{
          "query" => @data_fields_query,
          "variables" => variables
        })
        |> json_response(:ok)

      assert data_fields == []

      assert page_info == %{
               "endCursor" => nil,
               "hasNextPage" => false,
               "hasPreviousPage" => false,
               "startCursor" => nil
             }
    end

    @tag authentication: [role: "user", permissions: [:view_data_structure]]
    test "filters out data fields where user has no permissions", %{
      conn: conn,
      domain: %{id: domain_id}
    } do
      %{id: dsv_father_id, data_structure_id: data_structure_id} =
        insert(:data_structure_version,
          version: 1,
          class: "table",
          name: "table"
        )

      # structure with permissions in domain_id
      %{id: dsv_child_1_id} =
        insert(:data_structure_version,
          version: 1,
          class: "field",
          name: "field_1",
          data_structure: build(:data_structure, domain_ids: [domain_id])
        )

      # structure without permissions in domain_id
      %{id: dsv_child_2_id} =
        insert(:data_structure_version, version: 1, class: "field", name: "field_2")

      ## Structure relations
      create_relation(dsv_father_id, dsv_child_1_id)
      create_relation(dsv_father_id, dsv_child_2_id)

      variables = %{
        "dataStructureId" => data_structure_id,
        "version" => "latest"
      }

      %{"data" => %{"dataFields" => %{"page" => data_fields, "pageInfo" => page_info}}} =
        conn
        |> post("/api/v2", %{
          "query" => @data_fields_query,
          "variables" => variables
        })
        |> json_response(:ok)

      assert Enum.count(data_fields) == 1
      assert Enum.find(data_fields, &(String.to_integer(&1["id"]) == dsv_child_1_id))
      refute Enum.find(data_fields, &(String.to_integer(&1["id"]) == dsv_child_2_id))

      assert page_info["endCursor"]
      assert page_info["startCursor"]
      refute page_info["hasNextPage"]
      refute page_info["hasPreviousPage"]
    end

    @tag authentication: [role: "service"]
    test "returns data fields for version other than latest", %{conn: conn} do
      data_structure = insert(:data_structure)

      # initial version
      %{id: dsv_father_id} =
        insert(:data_structure_version,
          version: 0,
          class: "table",
          name: "table",
          data_structure_id: data_structure.id
        )

      %{id: dsv_child_1_id} =
        insert(:data_structure_version, version: 0, class: "field", name: "field_1")

      %{id: dsv_child_2_id} =
        insert(:data_structure_version, version: 0, class: "field", name: "field_2")

      create_relation(dsv_father_id, dsv_child_1_id)
      create_relation(dsv_father_id, dsv_child_2_id)

      # latest version
      %{id: dsv_father_id} =
        insert(:data_structure_version,
          version: 1,
          class: "table",
          name: "table",
          data_structure_id: data_structure.id
        )

      %{id: dsv_child_1_id} =
        insert(:data_structure_version, version: 1, class: "field", name: "field_1")

      create_relation(dsv_father_id, dsv_child_1_id)

      variables = %{
        "dataStructureId" => data_structure.id,
        "version" => "0"
      }

      %{"data" => %{"dataFields" => %{"page" => data_fields}}} =
        conn
        |> post("/api/v2", %{
          "query" => @data_fields_query,
          "variables" => variables
        })
        |> json_response(:ok)

      assert Enum.count(data_fields) == 2
      assert Enum.find(data_fields, &(&1["name"] == "field_1"))
      assert Enum.find(data_fields, &(&1["name"] == "field_2"))

      variables = %{
        "dataStructureId" => data_structure.id,
        "version" => "latest"
      }

      %{"data" => %{"dataFields" => %{"page" => data_fields}}} =
        conn
        |> post("/api/v2", %{
          "query" => @data_fields_query,
          "variables" => variables
        })
        |> json_response(:ok)

      assert Enum.count(data_fields) == 1
      assert Enum.find(data_fields, &(&1["name"] == "field_1"))
      refute Enum.find(data_fields, &(&1["name"] == "field_2"))
    end

    @tag authentication: [role: "service"]
    test "paginates over results sorted by name and metadata order", %{conn: conn} do
      %{id: dsv_father_id, data_structure_id: data_structure_id} =
        insert(:data_structure_version, version: 1, class: "table", name: "table")

      %{id: dsv_child_1_id} =
        insert(:data_structure_version,
          version: 1,
          class: "field",
          name: "field_1",
          metadata: %{"order" => "1"}
        )

      %{id: dsv_child_2_id} =
        insert(:data_structure_version,
          version: 1,
          class: "field",
          name: "field_2",
          metadata: %{"order" => "2"}
        )

      create_relation(dsv_father_id, dsv_child_1_id)
      create_relation(dsv_father_id, dsv_child_2_id)

      variables = %{
        "dataStructureId" => data_structure_id,
        "first" => 1,
        "version" => "latest"
      }

      %{"data" => %{"dataFields" => %{"page" => data_fields, "pageInfo" => page_info}}} =
        conn
        |> post("/api/v2", %{
          "query" => @data_fields_query,
          "variables" => variables
        })
        |> json_response(:ok)

      assert Enum.count(data_fields) == 1
      data_field = List.first(data_fields)
      assert data_field["name"] == "field_1"

      assert page_info["endCursor"]
      assert page_info["startCursor"]
      assert page_info["hasNextPage"]
      refute page_info["hasPreviousPage"]

      variables = %{
        "dataStructureId" => data_structure_id,
        "after" => page_info["endCursor"],
        "first" => 1,
        "version" => "latest"
      }

      %{"data" => %{"dataFields" => %{"page" => data_fields, "pageInfo" => page_info}}} =
        conn
        |> post("/api/v2", %{
          "query" => @data_fields_query,
          "variables" => variables
        })
        |> json_response(:ok)

      assert Enum.count(data_fields) == 1
      data_field = List.first(data_fields)
      assert data_field["name"] == "field_2"

      assert page_info["endCursor"]
      assert page_info["startCursor"]
      refute page_info["hasNextPage"]
      assert page_info["hasPreviousPage"]

      variables = %{
        "dataStructureId" => data_structure_id,
        "before" => page_info["endCursor"],
        "last" => 2,
        "version" => "latest"
      }

      %{"data" => %{"dataFields" => %{"page" => data_fields, "pageInfo" => page_info}}} =
        conn
        |> post("/api/v2", %{
          "query" => @data_fields_query,
          "variables" => variables
        })
        |> json_response(:ok)

      assert Enum.count(data_fields) == 1
      data_field = List.first(data_fields)
      assert data_field["name"] == "field_1"

      assert page_info["endCursor"]
      assert page_info["startCursor"]
      assert page_info["hasNextPage"]
      refute page_info["hasPreviousPage"]
    end

    @tag authentication: [role: "service"]
    test "searchs data fields by name", %{conn: conn} do
      %{id: dsv_father_id, data_structure_id: data_structure_id} =
        insert(:data_structure_version, version: 1, class: "table", name: "table")

      %{id: dsv_child_1_id} =
        insert(:data_structure_version, version: 1, class: "field", name: "field_1")

      %{id: dsv_child_2_id} =
        insert(:data_structure_version, version: 1, class: "field", name: "field_2")

      %{id: dsv_child_3_id} =
        insert(:data_structure_version, version: 1, class: "field", name: "name")

      create_relation(dsv_father_id, dsv_child_1_id)
      create_relation(dsv_father_id, dsv_child_2_id)
      create_relation(dsv_father_id, dsv_child_3_id)

      variables = %{
        "dataStructureId" => data_structure_id,
        "search" => "Iel",
        "version" => "latest"
      }

      %{"data" => %{"dataFields" => %{"page" => data_fields, "pageInfo" => page_info}}} =
        conn
        |> post("/api/v2", %{
          "query" => @data_fields_query,
          "variables" => variables
        })
        |> json_response(:ok)

      refute page_info["hasNextPage"]
      refute page_info["hasPreviousPage"]
      assert Enum.count(data_fields) == 2

      assert Enum.find(data_fields, &(&1["name"] == "field_1"))
      assert Enum.find(data_fields, &(&1["name"] == "field_2"))
      refute Enum.find(data_fields, &(&1["name"] == "name"))

      variables = %{
        "dataStructureId" => data_structure_id,
        "first" => 1,
        "search" => "Iel",
        "version" => "latest"
      }

      %{"data" => %{"dataFields" => %{"page" => data_fields, "pageInfo" => page_info}}} =
        conn
        |> post("/api/v2", %{
          "query" => @data_fields_query,
          "variables" => variables
        })
        |> json_response(:ok)

      assert page_info["hasNextPage"]
      refute page_info["hasPreviousPage"]
      assert Enum.count(data_fields) == 1

      variables = %{
        "dataStructureId" => data_structure_id,
        "search" => "me",
        "version" => "latest"
      }

      %{"data" => %{"dataFields" => %{"page" => data_fields, "pageInfo" => page_info}}} =
        conn
        |> post("/api/v2", %{
          "query" => @data_fields_query,
          "variables" => variables
        })
        |> json_response(:ok)

      refute page_info["hasNextPage"]
      refute page_info["hasPreviousPage"]
      assert Enum.count(data_fields) == 1
      assert Enum.find(data_fields, &(&1["name"] == "name"))
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

defmodule(QueryCounter) do
  def start, do: {:ok, _pid} = Agent.start_link(fn -> 0 end, name: :query_counter)
  def stop, do: Agent.stop(:query_counter)
  def total, do: Agent.get(:query_counter, & &1)
  def count(_, _, %{repo: TdDd.Repo}, _), do: Agent.update(:query_counter, &(&1 + 1))
end
