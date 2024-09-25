defmodule TdDd.DataStructures.DataStructureVersionsTest do
  use TdDd.DataCase
  use TdDd.GraphDataCase

  alias TdDd.DataStructures.DataStructureVersions
  alias TdDd.DataStructures.RelationTypes
  alias TdDd.Lineage.GraphData

  @moduletag sandbox: :shared

  setup do
    start_supervised!(TdDd.Search.StructureEnricher)
    start_supervised(GraphData)
    :ok
  end

  describe "enriched_data_structure_version/4" do
    test "enriches siblings" do
      claims = build(:claims)

      %{id: parent_id} = insert(:data_structure_version)
      %{id: id, data_structure_id: data_structure_id} = insert(:data_structure_version)
      %{id: sibling_id} = insert(:data_structure_version)

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

      assert [
               {:data_structure_version,
                %{
                  siblings: [
                    %{id: ^id},
                    %{id: ^sibling_id}
                  ]
                }}
               | _
             ] =
               DataStructureVersions.enriched_data_structure_version(
                 claims,
                 data_structure_id,
                 "latest",
                 [:siblings]
               )

      assert [{:data_structure_version, dsv} | _] =
               DataStructureVersions.enriched_data_structure_version(
                 claims,
                 data_structure_id,
                 "latest",
                 []
               )

      refute Map.has_key?(dsv, :siblings)
    end

    test "enriches data_fields" do
      claims = build(:claims)

      %{id: id, data_structure_id: data_structure_id} = insert(:data_structure_version)
      %{id: child_id} = insert(:data_structure_version, class: "field")
      %{id: non_field_child_id} = insert(:data_structure_version)

      relation_type_id = RelationTypes.default_id!()

      insert(:data_structure_relation,
        parent_id: id,
        child_id: child_id,
        relation_type_id: relation_type_id
      )

      insert(:data_structure_relation,
        parent_id: id,
        child_id: non_field_child_id,
        relation_type_id: relation_type_id
      )

      assert [{:data_structure_version, %{data_fields: [%{id: ^child_id}]}} | _] =
               DataStructureVersions.enriched_data_structure_version(
                 claims,
                 data_structure_id,
                 "latest",
                 [:data_fields]
               )

      assert [{:data_structure_version, dsv} | _] =
               DataStructureVersions.enriched_data_structure_version(
                 claims,
                 data_structure_id,
                 "latest",
                 []
               )

      assert [] = dsv.data_fields
    end

    test "enriches versions" do
      claims = build(:claims)

      data_structure = insert(:data_structure)

      %{id: old_version_id} =
        insert(:data_structure_version, data_structure: data_structure, version: 0)

      %{data_structure_id: data_structure_id, id: id} =
        insert(:data_structure_version, data_structure: data_structure, version: 1)

      assert [
               {:data_structure_version, %{versions: [%{id: ^old_version_id}, %{id: ^id}]}}
               | _
             ] =
               DataStructureVersions.enriched_data_structure_version(
                 claims,
                 data_structure_id,
                 "latest",
                 [:versions]
               )

      assert [{:data_structure_version, dsv} | _] =
               DataStructureVersions.enriched_data_structure_version(
                 claims,
                 data_structure_id,
                 "latest",
                 []
               )

      refute Map.has_key?(dsv, :versions)
    end

    test "enriches classes" do
      claims = build(:claims)

      %{data_structure_id: data_structure_id, id: id} = insert(:data_structure_version)

      %{class: class_value, name: class_name} =
        insert(:structure_classification, data_structure_version_id: id)

      assert [
               {:data_structure_version, %{classes: classes}}
               | _
             ] =
               DataStructureVersions.enriched_data_structure_version(
                 claims,
                 data_structure_id,
                 "latest",
                 []
               )

      assert %{class_name => class_value} == classes
    end

    test "enriches implementation_count" do
      claims = build(:claims)

      %{data_structure_id: data_structure_id} = insert(:data_structure_version)

      insert(:implementation_structure, data_structure_id: data_structure_id)
      insert(:implementation_structure, data_structure_id: data_structure_id)

      assert [
               {:data_structure_version, %{implementation_count: 2}}
               | _
             ] =
               DataStructureVersions.enriched_data_structure_version(
                 claims,
                 data_structure_id,
                 "latest",
                 [:implementation_count]
               )

      assert [{:data_structure_version, %{implementation_count: nil}} | _] =
               DataStructureVersions.enriched_data_structure_version(
                 claims,
                 data_structure_id,
                 "latest",
                 []
               )
    end

    test "enriches data_structure_link_count" do
      claims = build(:claims)

      %{data_structure_id: data_structure_id, data_structure: data_structure} =
        insert(:data_structure_version)

      another_data_structure = insert(:data_structure)

      test_label = insert(:label, name: "test_label")

      insert(:data_structure_link,
        source: data_structure,
        target: another_data_structure,
        labels: [test_label]
      )

      assert [
               {:data_structure_version, %{data_structure_link_count: 1}}
               | _
             ] =
               DataStructureVersions.enriched_data_structure_version(
                 claims,
                 data_structure_id,
                 "latest",
                 [:data_structure_link_count]
               )

      assert [{:data_structure_version, dsv} | _] =
               DataStructureVersions.enriched_data_structure_version(
                 claims,
                 data_structure_id,
                 "latest",
                 []
               )

      refute Map.has_key?(dsv, :data_structure_link_count)
    end

    test "enriches degree" do
      claims = build(:claims)

      %{data_structure: %{id: data_structure_id, external_id: external_id}} =
        insert(:data_structure_version)

      ### Graph
      contains = %{"foo" => [external_id, "baz"]}
      depends = [{external_id, "baz"}]

      GraphData.state(state: setup_state(%{contains: contains, depends: depends}))

      assert [
               {:data_structure_version, %{degree: %{in: 0, out: 1}}}
               | _
             ] =
               DataStructureVersions.enriched_data_structure_version(
                 claims,
                 data_structure_id,
                 "latest",
                 [:degree]
               )

      assert [{:data_structure_version, dsv} | _] =
               DataStructureVersions.enriched_data_structure_version(
                 claims,
                 data_structure_id,
                 "latest",
                 []
               )

      refute Map.has_key?(dsv, :degree)
    end

    test "enriches profile" do
      claims = build(:claims)

      %{data_structure_id: data_structure_id} = insert(:data_structure_version)

      insert(:profile,
        data_structure_id: data_structure_id,
        min: "1",
        max: "2",
        null_count: 5,
        most_frequent: ~s([["A", "76"]])
      )

      assert [
               {:data_structure_version,
                %{
                  profile: %{
                    max: "2",
                    min: "1",
                    most_frequent: [%{"k" => "A", "v" => 76}],
                    null_count: 5,
                    value: %{"foo" => "bar"}
                  }
                }}
               | _
             ] =
               DataStructureVersions.enriched_data_structure_version(
                 claims,
                 data_structure_id,
                 "latest",
                 [:profile]
               )

      assert [{:data_structure_version, dsv} | _] =
               DataStructureVersions.enriched_data_structure_version(
                 claims,
                 data_structure_id,
                 "latest",
                 []
               )

      refute Map.has_key?(dsv, :profile)
    end

    test "enriches source" do
      claims = build(:claims)

      %{id: source_id, external_id: source_external_id} = source = insert(:source)

      %{data_structure_id: data_structure_id} =
        insert(:data_structure_version, data_structure: build(:data_structure, source: source))

      assert [
               {:data_structure_version,
                %{
                  source: %{
                    id: ^source_id,
                    external_id: ^source_external_id
                  }
                }}
               | _
             ] =
               DataStructureVersions.enriched_data_structure_version(
                 claims,
                 data_structure_id,
                 "latest",
                 [:source]
               )

      assert [{:data_structure_version, dsv} | _] =
               DataStructureVersions.enriched_data_structure_version(
                 claims,
                 data_structure_id,
                 "latest",
                 []
               )

      refute Map.has_key?(dsv, :source)
    end

    test "enriches system" do
      claims = build(:claims)

      %{id: system_id, name: system_name} = system = insert(:system)

      %{data_structure_id: data_structure_id} =
        insert(:data_structure_version, data_structure: build(:data_structure, system: system))

      assert [
               {:data_structure_version,
                %{
                  system: %{
                    id: ^system_id,
                    name: ^system_name
                  }
                }}
               | _
             ] =
               DataStructureVersions.enriched_data_structure_version(
                 claims,
                 data_structure_id,
                 "latest",
                 [:system]
               )

      assert [{:data_structure_version, dsv} | _] =
               DataStructureVersions.enriched_data_structure_version(
                 claims,
                 data_structure_id,
                 "latest",
                 []
               )

      refute Map.has_key?(dsv, :system)
    end

    test "enriches grants" do
      %{user_id: user_id} = claims = build(:claims)

      %{data_structure_id: data_structure_id} = insert(:data_structure_version)

      start_date = Date.utc_today() |> Date.add(-1)
      end_date = Date.utc_today() |> Date.add(2)

      %{id: grant_id} =
        insert(:grant,
          data_structure_id: data_structure_id,
          user_id: user_id,
          start_date: start_date,
          end_date: end_date
        )

      assert [
               {:data_structure_version, %{grants: [%{id: ^grant_id}]}}
               | _
             ] =
               DataStructureVersions.enriched_data_structure_version(
                 claims,
                 data_structure_id,
                 "latest",
                 [:grants]
               )

      assert [{:data_structure_version, %{grants: nil}} | _] =
               DataStructureVersions.enriched_data_structure_version(
                 claims,
                 data_structure_id,
                 "latest",
                 []
               )
    end

    test "enriches grant" do
      %{user_id: user_id} = claims = build(:claims)

      %{data_structure_id: data_structure_id} = insert(:data_structure_version)

      start_date = Date.utc_today() |> Date.add(-1)
      end_date = Date.utc_today() |> Date.add(2)

      %{id: grant_id} =
        insert(:grant,
          data_structure_id: data_structure_id,
          user_id: user_id,
          start_date: start_date,
          end_date: end_date
        )

      assert [
               {:data_structure_version, %{grant: %{id: ^grant_id}}}
               | _
             ] =
               DataStructureVersions.enriched_data_structure_version(
                 claims,
                 data_structure_id,
                 "latest",
                 [:grant]
               )

      assert [{:data_structure_version, %{grant: nil}} | _] =
               DataStructureVersions.enriched_data_structure_version(
                 claims,
                 data_structure_id,
                 "latest",
                 []
               )
    end

    test "enriches links" do
      claims = build(:claims)

      %{data_structure_id: data_structure_id} = insert(:data_structure_version)

      %{id: concept_id, name: concept_name} = CacheHelpers.insert_concept()

      %{id: link_id} =
        CacheHelpers.insert_link(
          data_structure_id,
          "data_structure",
          "business_concept",
          concept_id
        )

      string_link_id = "#{link_id}"
      string_concept_id = "#{concept_id}"

      assert [
               {:data_structure_version,
                %{
                  links: [
                    %{
                      concept_count: 0,
                      content: %{},
                      domain: nil,
                      domain_id: nil,
                      id: ^string_link_id,
                      link_count: 1,
                      link_tags: [],
                      name: ^concept_name,
                      resource_id: ^string_concept_id,
                      resource_type: :concept,
                      rule_count: 0,
                      shared_to: [],
                      shared_to_ids: [],
                      tags: []
                    }
                  ]
                }}
               | _
             ] =
               DataStructureVersions.enriched_data_structure_version(
                 claims,
                 data_structure_id,
                 "latest",
                 [:links]
               )

      assert [{:data_structure_version, dsv} | _] =
               DataStructureVersions.enriched_data_structure_version(
                 claims,
                 data_structure_id,
                 "latest",
                 []
               )

      refute Map.has_key?(dsv, :links)
    end

    test "enriches relations" do
      claims = build(:claims)

      %{id: id, data_structure_id: data_structure_id} = insert(:data_structure_version)

      [
        %{id: parent_dsv_id},
        %{id: child_dsv_id}
      ] =
        ["parent", "child"]
        |> Enum.map(
          &insert(:data_structure_version, data_structure: build(:data_structure, external_id: &1))
        )

      %{id: relation_type_id} = insert(:relation_type)

      %{id: parent_relation_id} =
        insert(:data_structure_relation,
          parent_id: parent_dsv_id,
          child_id: id,
          relation_type_id: relation_type_id
        )

      %{id: child_relation_id} =
        insert(:data_structure_relation,
          parent_id: id,
          child_id: child_dsv_id,
          relation_type_id: relation_type_id
        )

      assert [
               {:data_structure_version,
                %{
                  relations: %{
                    parents: [
                      %{relation: %{id: ^parent_relation_id}, version: %{id: ^parent_dsv_id}}
                    ],
                    children: [
                      %{relation: %{id: ^child_relation_id}, version: %{id: ^child_dsv_id}}
                    ]
                  }
                }}
               | _
             ] =
               DataStructureVersions.enriched_data_structure_version(
                 claims,
                 data_structure_id,
                 "latest",
                 [:relations]
               )

      assert [{:data_structure_version, dsv} | _] =
               DataStructureVersions.enriched_data_structure_version(
                 claims,
                 data_structure_id,
                 "latest",
                 []
               )

      refute Map.has_key?(dsv, :relations)
    end

    test "enriches metadata" do
      claims = build(:claims)

      %{data_structure_id: data_structure_id} = insert(:data_structure_version)

      assert [
               {:data_structure_version,
                %{
                  metadata: %{"description" => "some description"}
                }}
               | _
             ] =
               DataStructureVersions.enriched_data_structure_version(
                 claims,
                 data_structure_id,
                 "latest",
                 []
               )
    end

    test "enriches note" do
      claims = build(:claims)

      %{data_structure_id: data_structure_id} = insert(:data_structure_version)

      insert(:structure_note,
        data_structure_id: data_structure_id,
        df_content: %{"foo" => %{"value" => "bar", "origin" => "user"}},
        status: :published
      )

      assert [
               {:data_structure_version,
                %{
                  published_note: %{
                    df_content: %{"foo" => %{"value" => "bar", "origin" => "user"}}
                  }
                }}
               | _
             ] =
               DataStructureVersions.enriched_data_structure_version(
                 claims,
                 data_structure_id,
                 "latest",
                 [:note]
               )

      assert [{:data_structure_version, %{published_note: %Ecto.Association.NotLoaded{}}} | _] =
               DataStructureVersions.enriched_data_structure_version(
                 claims,
                 data_structure_id,
                 "latest",
                 []
               )
    end

    test "returns _actions" do
      claims = build(:claims)

      %{data_structure_id: data_structure_id} = insert(:data_structure_version)

      assert [
               {:data_structure_version, _},
               {:tags, _},
               {:user_permissions, _},
               {:actions,
                %{
                  create_link: %{},
                  create_struct_to_struct_link: %{href: "/api/v2", method: "POST"},
                  manage_structure_acl_entry: %{}
                }}
             ] =
               DataStructureVersions.enriched_data_structure_version(
                 claims,
                 data_structure_id,
                 "latest"
               )
    end

    test "returns create_link action if user non admin has permissions" do
      %{id: user_id} = CacheHelpers.insert_user()

      claims = build(:claims, user_id: user_id, role: "user")

      %{id: domain_id} = CacheHelpers.insert_domain()

      CacheHelpers.put_session_permissions(claims, %{
        link_data_structure: [domain_id],
        view_data_structure: [domain_id],
        manage_business_concept_links: [domain_id]
      })

      data_structure = insert(:data_structure, domain_ids: [domain_id])

      %{data_structure_id: data_structure_id} =
        insert(:data_structure_version,
          data_structure: data_structure
        )

      assert [
               {:data_structure_version, _},
               {:tags, _},
               {:user_permissions, _},
               {:actions,
                %{
                  create_link: %{}
                }}
             ] =
               DataStructureVersions.enriched_data_structure_version(
                 claims,
                 data_structure_id,
                 "latest"
               )
    end

    test "returns empty actions if user non admin has not permissions" do
      for permission <- [:link_data_structure, :manage_business_concept_links] do
        %{id: user_id} = CacheHelpers.insert_user()

        claims = build(:claims, user_id: user_id, role: "user")

        %{id: domain_id} = CacheHelpers.insert_domain()

        permissions =
          Map.put(
            %{
              view_data_structure: [domain_id]
            },
            permission,
            [domain_id]
          )

        CacheHelpers.put_session_permissions(claims, permissions)

        data_structure = insert(:data_structure, domain_ids: [domain_id])

        %{data_structure_id: data_structure_id} =
          insert(:data_structure_version,
            data_structure: data_structure
          )

        assert [
                 {:data_structure_version, _},
                 {:tags, _},
                 {:user_permissions, _},
                 {:actions, %{}}
               ] =
                 DataStructureVersions.enriched_data_structure_version(
                   claims,
                   data_structure_id,
                   "latest"
                 )
      end
    end

    test "returns user_permissions" do
      claims = build(:claims)

      %{data_structure_id: data_structure_id} = insert(:data_structure_version)

      assert [
               {:data_structure_version, _},
               {:tags, _},
               {:user_permissions,
                %{
                  confidential: true,
                  create_foreign_grant_request: true,
                  profile_permission: false,
                  request_grant: false,
                  update: true,
                  update_domain: true,
                  update_grant_removal: true,
                  view_profiling_permission: true
                }},
               {:actions, _}
             ] =
               DataStructureVersions.enriched_data_structure_version(
                 claims,
                 data_structure_id,
                 "latest"
               )
    end

    test "returns user_permissions if user non admin dont has permissions" do
      %{id: user_id} = CacheHelpers.insert_user()

      claims = build(:claims, user_id: user_id, role: "user")

      %{id: domain_id} = CacheHelpers.insert_domain()

      CacheHelpers.put_session_permissions(claims, %{
        view_data_structure: [domain_id]
      })

      data_structure = insert(:data_structure, domain_ids: [domain_id])

      %{data_structure_id: data_structure_id} =
        insert(:data_structure_version,
          data_structure: data_structure
        )

      assert [
               {:data_structure_version, _},
               {:tags, _},
               {:user_permissions,
                %{
                  confidential: false,
                  create_foreign_grant_request: false,
                  profile_permission: false,
                  request_grant: false,
                  update: false,
                  update_domain: false,
                  update_grant_removal: false,
                  view_profiling_permission: false,
                  view_quality: false
                }},
               {:actions, _}
             ] =
               DataStructureVersions.enriched_data_structure_version(
                 claims,
                 data_structure_id,
                 "latest"
               )
    end

    test "returns user_permissions if user non admin has permissions" do
      %{id: user_id} = CacheHelpers.insert_user()

      claims = build(:claims, user_id: user_id, role: "user")

      %{id: domain_id} = CacheHelpers.insert_domain()

      CacheHelpers.put_session_permissions(claims, %{
        create_foreign_grant_request: [domain_id],
        create_grant_request: [domain_id],
        manage_confidential_structures: [domain_id],
        manage_foreign_grant_removal: [domain_id],
        manage_grant_removal: [domain_id],
        manage_structures_domain: [domain_id],
        update_data_structure: [domain_id],
        view_data_structure: [domain_id],
        view_data_structure: [domain_id],
        view_data_structures_profile: [domain_id],
        view_quality_rule: [domain_id]
      })

      data_structure = insert(:data_structure, domain_ids: [domain_id])

      %{data_structure_id: data_structure_id} =
        insert(:data_structure_version,
          data_structure: data_structure
        )

      assert [
               {:data_structure_version, _},
               {:tags, _},
               {:user_permissions,
                %{
                  confidential: true,
                  create_foreign_grant_request: true,
                  update: true,
                  update_domain: true,
                  update_grant_removal: true,
                  view_profiling_permission: true,
                  view_quality: true
                }},
               {:actions, _}
             ] =
               DataStructureVersions.enriched_data_structure_version(
                 claims,
                 data_structure_id,
                 "latest"
               )
    end
  end
end
