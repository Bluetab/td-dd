defmodule TdDd.DataStructuresTest do
  use TdDd.DataStructureCase

  import TdDd.TestOperators

  alias Elasticsearch.Document
  alias TdCache.Redix
  alias TdCache.Redix.Stream
  alias TdCore.Search.IndexWorkerMock
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.DataStructureVersion
  alias TdDd.DataStructures.Hierarchy
  alias TdDd.DataStructures.RelationTypes
  alias TdDd.DataStructures.StructureMetadata
  alias TdDd.Repo

  @moduletag sandbox: :shared
  @stream TdCache.Audit.stream()

  setup_all do
    on_exit(fn -> Redix.del!(@stream) end)
    [claims: build(:claims)]
  end

  setup do
    domain = CacheHelpers.insert_domain()
    %{id: template_id, name: template_name} = template = CacheHelpers.insert_template()

    CacheHelpers.insert_structure_type(name: template_name, template_id: template_id)

    %{id: system_id} = system = insert(:system, external_id: "test_system")

    %{id: data_structure_id} = data_structure = insert(:data_structure, system_id: system_id)

    data_structure_version =
      insert(:data_structure_version, data_structure: data_structure, type: template_name)

    %{id: concept_id} = concept = CacheHelpers.insert_concept()
    CacheHelpers.insert_link(data_structure_id, "data_structure", "business_concept", concept_id)

    start_supervised!(TdDd.Search.StructureEnricher)

    IndexWorkerMock.clear()

    [
      domain: domain,
      data_structure: data_structure,
      data_structure_version: data_structure_version,
      system: system,
      template: template,
      concept: concept
    ]
  end

  describe "update_data_structure/4" do
    test "updates confidential and domain_ids", %{
      data_structure: %{id: id} = data_structure,
      claims: claims
    } do
      params = %{confidential: true, domain_ids: [1, 2, 3]}

      assert {:ok, result} =
               DataStructures.update_data_structure(claims, data_structure, params, false)

      assert %{confidential: {1, [^id]}, domain_ids: {1, [^id]}, updated_ids: [^id]} = result
      assert %DataStructure{confidential: true} = Repo.get(DataStructure, id)
    end

    test "reindex implementations if updated domain_ids and has implementation_structure relation",
         %{
           data_structure: %{id: id} = data_structure,
           claims: claims
         } do
      %{id: implementation_id} = insert(:implementation, version: 1, status: :published)

      insert(:implementation_structure,
        data_structure_id: id,
        implementation_id: implementation_id
      )

      params = %{domain_ids: [1, 2, 3]}

      assert {:ok, result} =
               DataStructures.update_data_structure(claims, data_structure, params, false)

      assert {:reindex, :implementations, [^implementation_id]} =
               Enum.find(IndexWorkerMock.calls(), fn {action, index, _} ->
                 action == :reindex and index == :implementations
               end)

      assert %{domain_ids: {1, [^id]}, updated_ids: [^id]} = result
    end

    test "applies changes to descendents", %{claims: claims} do
      %{data_structure: data_structure, id: parent_id} = insert(:data_structure_version)
      %{data_structure_id: child_structure_id, id: child_id} = insert(:data_structure_version)

      insert(:data_structure_relation,
        parent_id: parent_id,
        child_id: child_id,
        relation_type_id: RelationTypes.default_id!()
      )

      params = %{domain_ids: [2, 3]}

      assert {:ok, result} =
               DataStructures.update_data_structure(claims, data_structure, params, true)

      assert %{domain_ids: {2, structure_ids}} = result
      assert_lists_equal(structure_ids, [data_structure.id, child_structure_id])
    end

    test "emits an audit event", %{data_structure: data_structure, claims: claims} do
      params = %{confidential: true}

      assert {:ok, %{audit: event_id}} =
               DataStructures.update_data_structure(claims, data_structure, params, false)

      assert {:ok, [%{id: ^event_id}]} =
               Stream.range(:redix, @stream, event_id, event_id, transform: :range)
    end
  end

  describe "delete_data_structure/2" do
    test "delete_data_structure/1 deletes the data_structure", %{
      data_structure: data_structure,
      claims: claims
    } do
      assert {:ok, %{data_structure: data_structure}} =
               DataStructures.delete_data_structure(data_structure, claims)

      assert %{__meta__: %{state: :deleted}} = data_structure
    end

    test "emits an audit event", %{data_structure: data_structure, claims: claims} do
      assert {:ok, %{audit: event_id}} =
               DataStructures.delete_data_structure(data_structure, claims)

      assert {:ok, [%{id: ^event_id}]} =
               Stream.range(:redix, @stream, event_id, event_id, transform: :range)
    end

    test "deletes a data_structure with relations", %{claims: claims} do
      ds1 = insert(:data_structure, id: 51, external_id: "DS51")
      ds2 = insert(:data_structure, id: 52, external_id: "DS52")
      ds3 = insert(:data_structure, id: 53, external_id: "DS53")
      dsv1 = insert(:data_structure_version, data_structure_id: ds1.id, name: ds1.external_id)
      dsv2 = insert(:data_structure_version, data_structure_id: ds2.id, name: ds1.external_id)
      dsv3 = insert(:data_structure_version, data_structure_id: ds3.id, name: ds1.external_id)

      relation_type_id = RelationTypes.default_id!()

      insert(:data_structure_relation,
        parent_id: dsv1.id,
        child_id: dsv2.id,
        relation_type_id: relation_type_id
      )

      insert(:data_structure_relation,
        parent_id: dsv1.id,
        child_id: dsv3.id,
        relation_type_id: relation_type_id
      )

      assert {:ok, %{data_structure: data_structure}} =
               DataStructures.delete_data_structure(ds1, claims)

      assert %{__meta__: %{state: :deleted}} = data_structure
      assert DataStructures.get_data_structure!(ds2.id) <~> ds2
      assert DataStructures.get_data_structure!(ds3.id) <~> ds3
    end
  end

  describe "logical_delete_data_structure/2" do
    test "logical_delete_data_structure/2 delete the logical data_structure version", %{
      data_structure_version: %{id: parent_version_id} = data_structure_version,
      data_structure: %{id: id},
      claims: claims
    } do
      insert(:structure_metadata, data_structure_id: id, version: parent_version_id)

      {:ok, result} = DataStructures.logical_delete_data_structure(data_structure_version, claims)

      assert %{delete_dsv_descendents: {1, nil}} = result
      assert %{delete_metadata_descendents: {1, nil}} = result
      assert %{data_structure_version_descendents: [^parent_version_id]} = result.descendents
      assert %{data_structures_ids: [^id]} = result.descendents
    end

    test "emits an audit event", %{data_structure_version: data_structure_version, claims: claims} do
      assert {:ok, %{audit: [event_id | _]}} =
               DataStructures.logical_delete_data_structure(data_structure_version, claims)

      assert {:ok, [%{id: ^event_id}]} =
               Stream.range(:redix, @stream, event_id, event_id, transform: :range)
    end
  end

  describe "get_metadata_version/1" do
    test "returns the latest version of the metadata overlapping with the data structure version" do
      %{id: id} = insert(:data_structure)

      [dsv1, dsv2, dsv3] =
        [
          [
            inserted_at: ~U[2020-01-01 00:00:00.123456Z],
            deleted_at: ~U[2020-02-01 00:00:00.123456Z]
          ],
          [
            inserted_at: ~U[2020-02-01 00:00:00.123456Z],
            deleted_at: ~U[2020-03-01 00:00:00.123456Z]
          ],
          [inserted_at: ~U[2020-04-01 00:00:00.123456Z]]
        ]
        |> Enum.with_index()
        |> Enum.map(fn {params, v} ->
          params |> Keyword.put(:data_structure_id, id) |> Keyword.put(:version, v)
        end)
        |> Enum.map(&insert(:data_structure_version, &1))

      [sm1, _sm2, sm3] =
        [
          [
            inserted_at: ~U[2020-02-02 00:00:00.123456Z],
            deleted_at: ~U[2020-02-03 00:00:00.123456Z]
          ],
          [
            inserted_at: ~U[2020-03-02 00:00:00.123456Z],
            deleted_at: ~U[2020-04-05 00:00:00.123456Z]
          ],
          [inserted_at: ~U[2020-05-01 00:00:00.123456Z]]
        ]
        |> Enum.with_index()
        |> Enum.map(fn {params, v} ->
          params |> Keyword.put(:data_structure_id, id) |> Keyword.put(:version, v)
        end)
        |> Enum.map(&insert(:structure_metadata, &1))

      assert DataStructures.get_metadata_version(dsv1) == nil
      assert DataStructures.get_metadata_version(dsv2) == sm1
      assert DataStructures.get_metadata_version(dsv3) == sm3
    end
  end

  describe "get_latest_versions/1" do
    test "returns the latest version of each structure_id" do
      %{id: id1} = insert(:data_structure)
      %{id: id2} = insert(:data_structure)

      for v <- Enum.shuffle(1..10) do
        insert(:data_structure_version, data_structure_id: id1, version: v)
        insert(:data_structure_version, data_structure_id: id2, version: v)
      end

      assert [%{version: 10}, %{version: 10}] =
               structures = DataStructures.get_latest_versions([id1, id2])

      assert [_, _] = structure_ids = Enum.map(structures, & &1.data_structure_id)
      assert id1 in structure_ids
      assert id2 in structure_ids
    end
  end

  describe "get_latest_version/1" do
    test "returns nil if first arg is nil" do
      assert DataStructures.get_latest_version(nil) == nil
    end

    test "enriches with path", %{
      data_structure_version: %{
        id: parent_id,
        data_structure_id: data_structure_id,
        name: parent_name
      }
    } do
      Hierarchy.update_hierarchy([data_structure_id])
      assert %{path: []} = DataStructures.get_latest_version(data_structure_id)

      %{child: %{data_structure_id: id}} =
        insert(:data_structure_relation,
          parent_id: parent_id,
          relation_type_id: RelationTypes.default_id!()
        )

      Hierarchy.update_hierarchy([parent_id])
      assert %{path: path} = DataStructures.get_latest_version(id)

      assert [%{"data_structure_id" => ^data_structure_id, "name" => ^parent_name}] = path
    end

    test "enriches data_structure with domain", %{
      domain: %{id: domain_id, name: domain_name, external_id: domain_external_id}
    } do
      %{data_structure_id: id} =
        insert(:data_structure_version,
          data_structure: build(:data_structure, domain_ids: [domain_id])
        )

      assert %{data_structure: data_structure} = DataStructures.get_latest_version(id)
      assert %{domains: [%{}] = [domain]} = data_structure
      assert %{id: ^domain_id, name: ^domain_name, external_id: ^domain_external_id} = domain
    end

    test "enriches with mutable_metadata" do
      %{data_structure_id: id} = insert(:data_structure_version)
      %{fields: fields} = insert(:structure_metadata, data_structure_id: id)

      assert %{mutable_metadata: ^fields} = DataStructures.get_latest_version(id)
    end

    test "enriches with filtered protected mutable_metadata" do
      %{data_structure_id: id} =
        insert(
          :data_structure_version,
          metadata: %{
            "m_foo" => "m_bar",
            DataStructures.protected() => %{
              "m_field1" => "m_field1",
              "m_field2" => "m_field2"
            }
          }
        )

      %{fields: _fields_with_protected} =
        insert(
          :structure_metadata,
          data_structure_id: id,
          fields: %{
            "mm_foo" => "mm_bar",
            DataStructures.protected() => %{
              "mm_field1" => "mm_field1",
              "mm_field2" => "mm_field2"
            }
          }
        )

      %{
        metadata: metadata,
        mutable_metadata: mutable_metadata
      } = DataStructures.get_latest_version(id)

      assert metadata == %{"m_foo" => "m_bar"}
      assert mutable_metadata == %{"mm_foo" => "mm_bar"}
    end

    test "enriches with protected mutable_metadata" do
      metadata = %{
        "m_foo" => "m_bar",
        DataStructures.protected() => %{
          "m_field1" => "m_field1",
          "m_field2" => "m_field2"
        }
      }

      mutable_metadata = %{
        "mm_foo" => "mm_bar",
        DataStructures.protected() => %{
          "mm_field1" => "mm_field1",
          "mm_field2" => "mm_field2"
        }
      }

      %{data_structure_id: id} =
        insert(
          :data_structure_version,
          metadata: metadata
        )

      insert(
        :structure_metadata,
        data_structure_id: id,
        fields: mutable_metadata
      )

      assert %{
               metadata: dsv_m,
               mutable_metadata: dsv_mm
             } = DataStructures.get_latest_version(id, [:with_protected_metadata])

      assert metadata == dsv_m
      assert mutable_metadata == dsv_mm
    end

    test "enriches with parents", %{
      data_structure_version: %{
        id: parent_id,
        name: parent_name
      }
    } do
      %{child: %{data_structure_id: id}} =
        insert(:data_structure_relation,
          parent_id: parent_id,
          relation_type_id: RelationTypes.default_id!()
        )

      assert %{parents: [%{id: ^parent_id, name: ^parent_name}]} =
               DataStructures.get_latest_version(id, [:parents])
    end
  end

  describe "enriched_structure_versions/1" do
    setup %{template: %{name: template_name}, domain: %{id: domain_id}} do
      data_structure = insert(:data_structure, domain_ids: [domain_id], alias: "baz")

      %{id: id, data_structure_id: data_structure_id} =
        data_structure_version =
        insert(:data_structure_version,
          data_structure: data_structure,
          type: template_name,
          class: "field"
        )

      profile = insert(:profile, data_structure_id: data_structure_id)

      insert(:structure_note,
        data_structure: data_structure,
        df_content: %{"string" => "initial", "list" => "one", "foo" => "bar"},
        status: :published
      )

      insert(:structure_metadata, data_structure_id: data_structure_id)

      yayo_structure = insert(:data_structure_version, name: "yayo")
      papa_structure = insert(:data_structure_version, name: "papa")

      %{parent_id: parent_id, parent: parent} =
        insert(:data_structure_relation,
          child_id: id,
          relation_type_id: RelationTypes.default_id!(),
          parent: papa_structure
        )

      %{parent: ancestor} =
        insert(:data_structure_relation,
          child_id: parent_id,
          relation_type_id: RelationTypes.default_id!(),
          parent: yayo_structure
        )

      insert(:structure_classification, data_structure_version_id: id, class: "bar", name: "foo")

      Hierarchy.update_hierarchy([id])

      [
        data_structure_version: data_structure_version,
        parent: parent,
        ancestor: ancestor,
        profile: profile
      ]
    end

    test "formats data_structure search_content and alias", %{data_structure_version: %{id: id}} do
      assert [dsv] =
               DataStructures.enriched_structure_versions(
                 ids: [id],
                 relation_type_id: RelationTypes.default_id!(),
                 content: :searchable
               )

      assert %{data_structure: data_structure} = dsv
      assert %{search_content: search_content} = data_structure
      assert %{alias: "baz"} = data_structure
      assert search_content == %{"string" => "initial", "list" => "one"}
    end

    test "returns values suitable for bulk-indexing encoding", %{
      data_structure_version: %{id: id, name: original_name},
      domain: %{id: domain_id, name: domain_name, external_id: domain_external_id}
    } do
      assert %{} =
               document =
               DataStructures.enriched_structure_versions(
                 ids: [id],
                 relation_type_id: RelationTypes.default_id!(),
                 content: :searchable
               )
               |> hd()
               |> Document.encode()

      assert %{
               with_content: true,
               classes: %{"foo" => "bar"},
               note: note,
               domain_ids: [^domain_id],
               metadata: %{"foo" => "bar"},
               domain: %{id: ^domain_id, name: ^domain_name, external_id: ^domain_external_id},
               path: path,
               path_sort: "yayo~papa",
               system: %{external_id: _, id: _, name: _},
               name: "baz",
               original_name: ^original_name
             } = document

      assert note == %{"list" => "one", "string" => "initial"}

      assert ["yayo", "papa"] = path
    end

    test "returns profile flag", %{
      data_structure_version: %{id: id},
      parent: %{id: parent_id},
      ancestor: %{id: ancestor_id}
    } do
      versions =
        DataStructures.enriched_structure_versions(
          ids: [id, parent_id, ancestor_id],
          relation_type_id: RelationTypes.default_id!(),
          content: :searchable
        )

      assert %{with_profiling: true} = Enum.find(versions, &(&1.id == id))
      assert %{with_profiling: true} = Enum.find(versions, &(&1.id == parent_id))
      assert %{with_profiling: false} = Enum.find(versions, &(&1.id == ancestor_id))
    end

    test "extracts metadata filters" do
      %{data_structure_id: id, type: type} =
        insert(:data_structure_version, metadata: %{"foo" => "foo", "bar" => [%{"bar" => "bar"}]})

      insert(:structure_metadata,
        data_structure_id: id,
        fields: %{"baz" => ["baz1", "baz2"], "xyzzy" => nil}
      )

      assert [%{_filters: filters}] =
               DataStructures.enriched_structure_versions(
                 data_structure_ids: [id],
                 relation_type_id: RelationTypes.default_id!(),
                 filters: %{type => ["foo", "bar", "baz", "xyzzy"]}
               )

      assert filters == %{"baz" => ["baz1", "baz2"], "foo" => "foo"}
    end

    test "gets protected metadata" do
      metadata = %{
        "m_foo" => "m_bar",
        DataStructures.protected() => %{
          "m_field1" => "m_field1",
          "m_field2" => "m_field2"
        }
      }

      mutable_metadata = %{
        "mm_foo" => "mm_bar",
        DataStructures.protected() => %{
          "mm_field1" => "mm_field1",
          "mm_field2" => "mm_field2"
        }
      }

      %{data_structure_id: id} = insert(:data_structure_version, metadata: metadata)

      insert(:structure_metadata,
        data_structure_id: id,
        fields: mutable_metadata
      )

      assert [%{metadata: result_metadata, mutable_metadata: result_mm}] =
               DataStructures.enriched_structure_versions(
                 data_structure_ids: [id],
                 relation_type_id: RelationTypes.default_id!(),
                 with_protected_metadata: true
               )

      assert result_metadata == metadata
      assert result_mm == mutable_metadata
    end

    test "filters protected metadata" do
      metadata = %{
        "m_foo" => "m_bar",
        DataStructures.protected() => %{
          "m_field1" => "m_field1",
          "m_field2" => "m_field2"
        }
      }

      mutable_metadata = %{
        "mm_foo" => "mm_bar",
        DataStructures.protected() => %{
          "mm_field1" => "mm_field1",
          "mm_field2" => "mm_field2"
        }
      }

      %{data_structure_id: id} = insert(:data_structure_version, metadata: metadata)

      insert(:structure_metadata,
        data_structure_id: id,
        fields: mutable_metadata
      )

      assert [%{metadata: result_metadata, mutable_metadata: result_mm}] =
               DataStructures.enriched_structure_versions(
                 data_structure_ids: [id],
                 relation_type_id: RelationTypes.default_id!(),
                 with_protected_metadata: false
               )

      assert result_metadata == %{"m_foo" => "m_bar"}
      assert result_mm == %{"mm_foo" => "mm_bar"}
    end
  end

  describe "template_name/1" do
    test "returns an empty string if no template or type exists" do
      %{name: type} = insert(:data_structure_type)
      dsv = insert(:data_structure_version, type: type)
      assert DataStructures.template_name(dsv) == ""

      dsv = insert(:data_structure_version)
      assert DataStructures.template_name(dsv) == ""
    end

    test "returns the name of the corresponding template" do
      %{id: template_id, name: name} = CacheHelpers.insert_template()
      %{name: type} = insert(:data_structure_type, template_id: template_id)
      dsv = insert(:data_structure_version, type: type)
      assert DataStructures.template_name(dsv) == name
    end
  end

  describe "data_structures" do
    @update_attrs %{
      # description: "some updated description",
      df_content: %{"string" => "changed", "list" => "two"}
    }
    @invalid_attrs %{
      description: nil,
      group: nil,
      last_change_by: nil,
      name: nil
    }

    test "list_data_structures/1 returns all data_structures", %{data_structure: data_structure} do
      assert DataStructures.list_data_structures() <~> [data_structure]
    end

    test "list_data_structures/1 returns all data_structures from a search", %{
      data_structure: data_structure
    } do
      search_params = %{external_id: [data_structure.external_id]}

      assert DataStructures.list_data_structures(search_params), [data_structure]
    end

    test "list_data_structures_data_fields/1 returns all data_fields by data_structure" do
      domain1 = CacheHelpers.insert_domain()
      domain2 = CacheHelpers.insert_domain()
      domain3 = CacheHelpers.insert_domain()

      claims = build(:claims, role: "user")

      CacheHelpers.put_session_permissions(claims, %{
        "view_data_structure" => [domain2.id, domain3.id],
        "manage_confidential_structures" => [domain3.id]
      })

      [%{data_structure_id: data_structure_id} = dsv] =
        ["structure"]
        |> Enum.map(&insert(:data_structure, external_id: &1))
        |> Enum.map(&insert(:data_structure_version, data_structure_id: &1.id))

      fields =
        [
          %{external_id: "domain_1_not_conf", domain_id: domain1.id, confidential: false},
          %{external_id: "domain_1_conf", domain_id: domain1.id, confidential: true},
          %{external_id: "domain_2_not_conf", domain_id: domain2.id, confidential: false},
          %{external_id: "domain_2_conf", domain_id: domain2.id, confidential: true},
          %{external_id: "domain_3_not_conf", domain_id: domain3.id, confidential: false},
          %{external_id: "domain_3_conf", domain_id: domain3.id, confidential: true}
        ]
        |> Enum.map(
          &insert(:data_structure,
            external_id: &1.external_id,
            domain_ids: [&1.domain_id],
            confidential: &1.confidential
          )
        )
        |> Enum.map(&insert(:data_structure_version, data_structure_id: &1.id, class: "field"))

      relation_type_id = RelationTypes.default_id!()

      Enum.map(
        fields,
        &insert(:data_structure_relation,
          parent_id: dsv.id,
          child_id: &1.id,
          relation_type_id: relation_type_id
        )
      )

      assert [
               %{
                 id: ^data_structure_id,
                 data_field: %{data_structure: %{external_id: "domain_2_not_conf"}}
               },
               %{
                 id: ^data_structure_id,
                 data_field: %{data_structure: %{external_id: "domain_3_not_conf"}}
               },
               %{
                 id: ^data_structure_id,
                 data_field: %{data_structure: %{external_id: "domain_3_conf"}}
               }
             ] = DataStructures.list_data_structures_data_fields([data_structure_id], claims)

      admin_claims = build(:claims)

      assert [
               %{
                 id: ^data_structure_id,
                 data_field: %{data_structure: %{external_id: "domain_1_not_conf"}}
               },
               %{
                 id: ^data_structure_id,
                 data_field: %{data_structure: %{external_id: "domain_1_conf"}}
               },
               %{
                 id: ^data_structure_id,
                 data_field: %{data_structure: %{external_id: "domain_2_not_conf"}}
               },
               %{
                 id: ^data_structure_id,
                 data_field: %{data_structure: %{external_id: "domain_2_conf"}}
               },
               %{
                 id: ^data_structure_id,
                 data_field: %{data_structure: %{external_id: "domain_3_not_conf"}}
               },
               %{
                 id: ^data_structure_id,
                 data_field: %{data_structure: %{external_id: "domain_3_conf"}}
               }
             ] =
               DataStructures.list_data_structures_data_fields([data_structure_id], admin_claims)
    end

    test "get_data_structure!/1 returns the data_structure with given id", %{
      data_structure: data_structure
    } do
      assert DataStructures.get_data_structure!(data_structure.id) <~> data_structure
    end

    test "get_data_structure_by_external_id/1 returns the data_structure with metadata versions",
         %{data_structure: data_structure} do
      assert DataStructures.get_data_structure_by_external_id(data_structure.external_id)
             <~> data_structure
    end

    test "get_data_structure!/1 returns error when structure does not exist" do
      assert_raise Ecto.NoResultsError, fn -> DataStructures.get_data_structure!(1) end
    end

    test "find_data_structure/1 returns a data structure", %{data_structure: data_structure} do
      %{id: id, external_id: external_id} = data_structure
      result = DataStructures.find_data_structure(%{external_id: external_id})

      assert %DataStructure{} = result
      assert result.id == id
      assert result.external_id == external_id
    end
  end

  describe "data structure versions" do
    test "get_siblings/1 returns sibling structure versions" do
      %{id: system_id} = insert(:system)

      [ds1, ds2, ds3, ds4] =
        1..4
        |> Enum.map(
          &insert(
            :data_structure,
            external_id: "DS#{&1}",
            system_id: system_id
          )
        )

      [dsv1, dsv2, dsv3, dsv4] =
        [ds1, ds2, ds3, ds4]
        |> Enum.map(
          &insert(:data_structure_version, data_structure_id: &1.id, name: &1.external_id)
        )

      relation_type_id = RelationTypes.default_id!()

      [{dsv1, dsv2}, {dsv1, dsv3}, {dsv2, dsv4}, {dsv3, dsv4}]
      |> Enum.map(fn {parent, child} ->
        insert(:data_structure_relation,
          parent_id: parent.id,
          child_id: child.id,
          relation_type_id: relation_type_id
        )
      end)

      assert DataStructures.get_siblings(dsv1) == []
      assert DataStructures.get_siblings(dsv2) ||| [dsv2, dsv3]
      assert DataStructures.get_siblings(dsv3) ||| [dsv2, dsv3]
      assert DataStructures.get_siblings(dsv4) ||| [dsv4]
    end

    test "delete_data_structure/1 deletes a data_structure with relations", %{claims: claims} do
      ds1 = insert(:data_structure, id: 51, external_id: "DS51")
      ds2 = insert(:data_structure, id: 52, external_id: "DS52")
      ds3 = insert(:data_structure, id: 53, external_id: "DS53")
      dsv1 = insert(:data_structure_version, data_structure_id: ds1.id, name: ds1.external_id)
      dsv2 = insert(:data_structure_version, data_structure_id: ds2.id, name: ds1.external_id)
      dsv3 = insert(:data_structure_version, data_structure_id: ds3.id, name: ds1.external_id)

      relation_type_id = RelationTypes.default_id!()

      insert(:data_structure_relation,
        parent_id: dsv1.id,
        child_id: dsv2.id,
        relation_type_id: relation_type_id
      )

      insert(:data_structure_relation,
        parent_id: dsv1.id,
        child_id: dsv3.id,
        relation_type_id: relation_type_id
      )

      assert {:ok, %{} = reply} = DataStructures.delete_data_structure(ds1, claims)
      data_structure = Map.get(reply, :data_structure)

      assert %{__meta__: %{state: :deleted}} = data_structure

      assert_raise Ecto.NoResultsError, fn ->
        DataStructures.get_data_structure!(ds1.id)
      end

      assert DataStructures.get_data_structure!(ds2.id) <~> ds2
      assert DataStructures.get_data_structure!(ds3.id) <~> ds3
    end

    test "get_data_structure_version!/2 enriches with parents, children, siblings and relations" do
      [dsv, parent, child, sibling] =
        ["structure", "parent", "child", "sibling"]
        |> Enum.map(&insert(:data_structure, external_id: &1))
        |> Enum.map(&insert(:data_structure_version, data_structure_id: &1.id))

      relation_type_id = RelationTypes.default_id!()

      insert(:data_structure_relation,
        parent_id: parent.id,
        child_id: dsv.id,
        relation_type_id: relation_type_id
      )

      insert(:data_structure_relation,
        parent_id: parent.id,
        child_id: sibling.id,
        relation_type_id: relation_type_id
      )

      insert(:data_structure_relation,
        parent_id: dsv.id,
        child_id: child.id,
        relation_type_id: relation_type_id
      )

      enrich_opts = [:parents, :children, :siblings, :relations]

      assert %{
               id: id,
               parents: parents,
               children: children,
               siblings: siblings,
               relations: relations
             } = DataStructures.get_data_structure_version!(dsv.id, enrich_opts)

      assert id == dsv.id
      assert parents ||| [parent]
      assert children ||| [child]
      assert siblings ||| [sibling, dsv]
      assert relations.parents == []
      assert relations.children == []
    end

    test "get_data_structure_version!/2 enriches with protecting metadata, except parents, siblings and children." do
      %{
        dsv: dsv,
        parent_dsv: parent,
        child_dsv: child,
        sibling_dsv: sibling,
        metadata: metadata_with_protected,
        mutable_metadata: mutable_metadata_with_protected
      } = create_hierarchy_with_protected_metadata()

      enrich_opts = [:parents, :children, :siblings, :relations, :with_protected_metadata]

      assert %{
               id: id,
               parents: [result_parent] = parents,
               children: [result_child] = children,
               siblings: [result_sibling, result_dsv] = siblings,
               relations: relations,
               metadata: dsv_m,
               mutable_metadata: dsv_mm
             } = DataStructures.get_data_structure_version!(dsv.id, enrich_opts)

      assert dsv_m == metadata_with_protected
      assert dsv_mm == mutable_metadata_with_protected
      assert id == dsv.id
      # Parents, children and siblings have always their metadata removed, even
      # when enriched :with_protected_metadata
      assert parents ||| [%{parent | metadata: %{"m_foo" => "m_bar"}}]
      assert result_parent.metadata == %{"m_foo" => "m_bar"}
      # Enriched parents, children and siblings do not have mutable_metadata loaded.
      assert result_parent.mutable_metadata == nil
      assert children ||| [%{child | metadata: %{"m_foo" => "m_bar"}}]
      assert result_child.metadata == %{"m_foo" => "m_bar"}
      assert result_child.mutable_metadata == nil

      assert siblings |||
               [
                 %{sibling | metadata: %{"m_foo" => "m_bar"}},
                 %{dsv | metadata: %{"m_foo" => "m_bar"}}
               ]

      assert result_sibling.metadata == %{"m_foo" => "m_bar"}
      assert result_sibling.mutable_metadata == nil
      assert result_dsv.metadata == %{"m_foo" => "m_bar"}
      assert result_dsv.mutable_metadata == nil
      assert relations.parents == []
      assert relations.children == []
    end

    test "get_data_structure_version!/2 enriches with parents, children, siblings and relations, filtering protected metadata" do
      %{
        dsv: dsv,
        parent_dsv: parent,
        child_dsv: child,
        sibling_dsv: sibling
      } = create_hierarchy_with_protected_metadata()

      enrich_opts = [:parents, :children, :siblings, :relations]

      assert %{
               id: id,
               parents: [result_parent] = parents,
               children: [result_child] = children,
               siblings: [result_sibling, result_dsv] = siblings,
               relations: relations,
               metadata: dsv_m,
               mutable_metadata: dsv_mm
             } = DataStructures.get_data_structure_version!(dsv.id, enrich_opts)

      assert dsv_m == %{"m_foo" => "m_bar"}
      assert dsv_mm == %{"mm_foo" => "mm_bar"}
      assert id == dsv.id
      assert parents ||| [%{parent | metadata: %{"m_foo" => "m_bar"}}]
      assert result_parent.metadata == %{"m_foo" => "m_bar"}
      # Enriched parents, children and siblings do not have mutable_metadata loaded.
      assert result_parent.mutable_metadata == nil
      assert children ||| [%{child | metadata: %{"m_foo" => "m_bar"}}]
      assert result_child.metadata == %{"m_foo" => "m_bar"}
      assert result_child.mutable_metadata == nil

      assert siblings |||
               [
                 %{sibling | metadata: %{"m_foo" => "m_bar"}},
                 %{dsv | metadata: %{"m_foo" => "m_bar"}}
               ]

      assert result_sibling.metadata == %{"m_foo" => "m_bar"}
      assert result_sibling.mutable_metadata == nil
      assert result_dsv.metadata == %{"m_foo" => "m_bar"}
      assert result_dsv.mutable_metadata == nil
      assert relations.parents == []
      assert relations.children == []
    end

    test "get_data_structure_version!/2 enriches with classifications" do
      %{data_structure_version_id: data_structure_version_id, id: id, name: name, class: class} =
        insert(:structure_classification)

      assert %{classifications: classifications} =
               DataStructures.get_data_structure_version!(data_structure_version_id, [
                 :classifications
               ])

      assert [%{id: ^id, name: ^name, class: ^class}] = classifications
    end

    test "get_data_structure_version!/2 with options: parents, children, siblings, with_confidential enriches including confidential" do
      [dsv, parent, child, sibling, r_child] =
        ["structure", "parent", "child", "sibling", "r_child"]
        |> Enum.map(&insert(:data_structure, external_id: &1))
        |> Enum.map(&insert(:data_structure_version, data_structure_id: &1.id))

      [child_confidential, sibling_confidential, r_child_confidential] =
        ["child_confidential", "sibling_confidential", "r_child_confidential"]
        |> Enum.map(&insert(:data_structure, external_id: &1, confidential: true))
        |> Enum.map(&insert(:data_structure_version, data_structure_id: &1.id))

      fields =
        ["field1", "field2", "field3"]
        |> Enum.map(&insert(:data_structure, external_id: &1))
        |> Enum.map(&insert(:data_structure_version, data_structure_id: &1.id, class: "field"))

      field_confidential =
        ["field4_confidential"]
        |> Enum.map(&insert(:data_structure, external_id: &1, confidential: true))
        |> Enum.map(&insert(:data_structure_version, data_structure_id: &1.id, class: "field"))

      %{id: custom_relation_id} = insert(:relation_type, name: "relation_type_1")
      relation_type_id = RelationTypes.default_id!()

      Enum.map(
        fields ++ field_confidential,
        &insert(:data_structure_relation,
          parent_id: dsv.id,
          child_id: &1.id,
          relation_type_id: relation_type_id
        )
      )

      insert(:data_structure_relation,
        parent_id: parent.id,
        child_id: dsv.id,
        relation_type_id: relation_type_id
      )

      insert(:data_structure_relation,
        parent_id: parent.id,
        child_id: sibling.id,
        relation_type_id: relation_type_id
      )

      insert(:data_structure_relation,
        parent_id: parent.id,
        child_id: sibling_confidential.id,
        relation_type_id: relation_type_id
      )

      insert(:data_structure_relation,
        parent_id: dsv.id,
        child_id: child.id,
        relation_type_id: relation_type_id
      )

      insert(:data_structure_relation,
        parent_id: dsv.id,
        child_id: r_child.id,
        relation_type_id: custom_relation_id
      )

      insert(:data_structure_relation,
        parent_id: dsv.id,
        child_id: r_child_confidential.id,
        relation_type_id: custom_relation_id
      )

      insert(:data_structure_relation,
        parent_id: dsv.id,
        child_id: child_confidential.id,
        relation_type_id: relation_type_id
      )

      enrich_opts = [:parents, :children, :siblings, :relations, :data_fields]

      assert %{
               id: id,
               parents: parents,
               children: children,
               siblings: siblings,
               relations: relations,
               data_fields: data_fields
             } = DataStructures.get_data_structure_version!(dsv.id, enrich_opts)

      assert id == dsv.id
      assert parents ||| [parent]
      assert children ||| [child] ++ fields
      assert siblings ||| [sibling, dsv]
      assert data_fields ||| fields
      assert %{children: [child_relation]} = relations
      assert child_relation.version <~> r_child

      enrich_opts = [:parents, :children, :siblings, :with_confidential, :relations]

      assert %{
               id: id,
               parents: parents,
               children: children,
               siblings: siblings,
               relations: relations
             } = DataStructures.get_data_structure_version!(dsv.id, enrich_opts)

      assert id == dsv.id
      assert parents ||| [parent]
      assert children ||| [child, child_confidential] ++ fields ++ field_confidential
      assert siblings ||| [sibling, dsv, sibling_confidential]
      assert %{children: child_rels} = relations
      assert Enum.find(child_rels, &(&1.version.id == r_child.id)).version <~> r_child

      assert Enum.find(child_rels, &(&1.version.id == r_child_confidential.id)).version
             <~> r_child_confidential
    end

    test "get_data_structure_version!/1 returns the data_structure with given id", %{
      data_structure_version: data_structure_version
    } do
      assert DataStructures.get_data_structure_version!(data_structure_version.id)
             <~> data_structure_version
    end

    test "get_data_structure_version!/1 enriches with path" do
      %{id: id} =
        ["foo", "bar", "baz", "xyzzy", "spqr"]
        |> create_hierarchy()
        |> Enum.at(4)

      Hierarchy.update_hierarchy([id])
      assert %{path: path} = DataStructures.get_data_structure_version!(id)
      assert Enum.map(path, & &1["name"]) == ["foo", "bar", "baz", "xyzzy"]
    end

    test "get_data_structure_version!/1 enriches with path and aliases" do
      dsvs =
        ["foo", "original_name", "baz", "xyzzy", "spqr"]
        |> create_hierarchy()

      %{id: id} = Enum.at(dsvs, 4)

      assert %{path: path} = DataStructures.get_data_structure_version!(id)
      assert Enum.map(path, & &1["name"]) == ["foo", "alias_name", "baz", "xyzzy"]
    end

    test "get_data_structure_version!/2 excludes deleted children if structure is not deleted" do
      %{id: system_id} = insert(:system)

      [dsv, child, deleted_child] =
        ["structure", "child", "deleted_child"]
        |> Enum.map(&insert(:data_structure, external_id: &1, system_id: system_id))
        |> Enum.map(
          &insert(:data_structure_version, data_structure_id: &1.id, deleted_at: deleted_at(&1))
        )

      relation_type_id = RelationTypes.default_id!()

      insert(:data_structure_relation,
        parent_id: dsv.id,
        child_id: child.id,
        relation_type_id: relation_type_id
      )

      insert(:data_structure_relation,
        parent_id: dsv.id,
        child_id: deleted_child.id,
        relation_type_id: relation_type_id
      )

      assert %{children: children} =
               DataStructures.get_data_structure_version!(dsv.id, [:children])

      assert children ||| [child]
    end

    test "get_data_structure_version!/2 gets custom relations", %{
      data_structure_version: child_custom_relation,
      concept: %{id: concept_id}
    } do
      [
        dsv,
        parent,
        parent_custom_relation,
        child,
        sibling
      ] =
        [
          "structure",
          "parent",
          "parent_custom_relation",
          "child",
          "sibling"
        ]
        |> Enum.map(&insert(:data_structure, external_id: &1))
        |> Enum.map(&insert(:data_structure_version, data_structure_id: &1.id))

      %{id: custom_id} = insert(:relation_type, name: "relation_type_1")
      default_id = RelationTypes.default_id!()

      insert(:data_structure_relation,
        parent_id: parent.id,
        child_id: dsv.id,
        relation_type_id: default_id
      )

      insert(:data_structure_relation,
        parent_id: parent_custom_relation.id,
        child_id: dsv.id,
        relation_type_id: custom_id
      )

      insert(:data_structure_relation,
        parent_id: parent.id,
        child_id: sibling.id,
        relation_type_id: default_id
      )

      insert(:data_structure_relation,
        parent_id: dsv.id,
        child_id: child_custom_relation.id,
        relation_type_id: custom_id
      )

      insert(:data_structure_relation,
        parent_id: dsv.id,
        child_id: child.id,
        relation_type_id: default_id
      )

      enrich_opts = [:parents, :children, :siblings, :relations, :relation_links]

      assert %{
               id: id,
               parents: parents,
               children: children,
               siblings: siblings,
               relations: relations
             } = DataStructures.get_data_structure_version!(dsv.id, enrich_opts)

      assert id == dsv.id
      assert parents ||| [parent]
      assert children ||| [child]
      assert siblings ||| [sibling, dsv]
      assert %{parents: [parent_relation], children: [child_relation]} = relations
      assert parent_relation.version <~> parent_custom_relation
      assert child_relation.version <~> child_custom_relation
      assert [link] = child_relation.links
      assert %{resource_type: :concept, resource_id: resource_id} = link
      assert resource_id == to_string(concept_id)
    end

    defp deleted_at(%{external_id: "deleted_child"}), do: DateTime.utc_now()
    defp deleted_at(_), do: nil

    test "get_data_structure_version!/2 includes deleted children if structure is deleted" do
      [dsv | deleted_children] =
        ["structure", "child", "child2"]
        |> Enum.map(&insert(:data_structure, external_id: &1))
        |> Enum.map(
          &insert(:data_structure_version,
            data_structure_id: &1.id,
            deleted_at: DateTime.utc_now()
          )
        )

      relation_type_id = RelationTypes.default_id!()

      Enum.each(
        deleted_children,
        &insert(:data_structure_relation,
          parent_id: dsv.id,
          child_id: &1.id,
          relation_type_id: relation_type_id
        )
      )

      assert %{children: children} =
               DataStructures.get_data_structure_version!(dsv.id, [:children])

      assert children ||| deleted_children
    end

    test "get_data_structure_version!/2 enriches with fields" do
      [dsv | fields] =
        ["structure", "field1", "field2", "field3"]
        |> Enum.map(&insert(:data_structure, external_id: "get_data_structure_version!/2 " <> &1))
        |> Enum.map(&insert(:data_structure_version, data_structure_id: &1.id, class: "field"))

      relation_type_id = RelationTypes.default_id!()

      Enum.map(
        fields,
        &insert(:data_structure_relation,
          parent_id: dsv.id,
          child_id: &1.id,
          relation_type_id: relation_type_id
        )
      )

      assert %{data_fields: data_fields} =
               DataStructures.get_data_structure_version!(dsv.id, [:data_fields])

      assert data_fields ||| fields
    end

    test "get_data_structure_version!/2 enriches with versions", %{system: system} do
      ds = insert(:data_structure, system_id: system.id)

      [dsv | dsvs] =
        0..3
        |> Enum.map(&insert(:data_structure_version, data_structure_id: ds.id, version: &1))

      assert %{versions: versions} =
               DataStructures.get_data_structure_version!(dsv.id, [:versions])

      assert versions ||| [dsv | dsvs]
    end

    test "get_data_structure_version!/2 enriches with system", %{
      data_structure_version: dsv,
      system: sys
    } do
      assert %{system: system} = DataStructures.get_data_structure_version!(dsv.id, [:system])

      assert system == sys
    end

    test "get_data_structure_version!/1 enriches data structure with domain", %{
      domain: %{id: domain_id, name: domain_name, external_id: domain_external_id}
    } do
      %{id: id} =
        insert(:data_structure_version,
          data_structure: insert(:data_structure, domain_ids: [domain_id])
        )

      assert %{data_structure: data_structure} = DataStructures.get_data_structure_version!(id)
      assert %{domains: [domain]} = data_structure
      assert %{id: ^domain_id, name: ^domain_name, external_id: ^domain_external_id} = domain
    end

    test "get_data_structure_version!/1 enriches data structure with domain parents", _ do
      %{id: d1_id, name: d1_name, external_id: d1_ext_id} = CacheHelpers.insert_domain()

      %{id: d2_id, name: d2_name, external_id: d2_ext_id} =
        CacheHelpers.insert_domain(%{parent_id: d1_id})

      %{id: d3_id, name: d3_name, external_id: d3_ext_id} =
        CacheHelpers.insert_domain(%{parent_id: d2_id})

      %{id: id} =
        insert(:data_structure_version,
          data_structure:
            build(:data_structure,
              domain_ids: [d3_id]
            )
        )

      assert %{data_structure: data_structure} = DataStructures.get_data_structure_version!(id)
      assert %{domains: [domain]} = data_structure

      assert %{
               name: ^d3_name,
               external_id: ^d3_ext_id,
               parents: [
                 %{id: ^d1_id, name: ^d1_name, external_id: ^d1_ext_id},
                 %{id: ^d2_id, name: ^d2_name, external_id: ^d2_ext_id}
               ]
             } = domain
    end

    test "get_data_structure_version!/1 enriches with empty map when there is no domain",
         %{data_structure_version: %{id: id}} do
      assert %{data_structure: data_structure} = DataStructures.get_data_structure_version!(id)
      assert %{domains: domains} = data_structure
      assert domains == [%{}]
    end

    test "get_data_structure_version!/3 enriches specified version" do
      %{
        child: %{id: id1, data_structure_id: id, version: version},
        parent: %{data_structure_id: parent_id1}
      } =
        insert(:data_structure_relation,
          relation_type_id: RelationTypes.default_id!(),
          child: build(:data_structure_version, deleted_at: DateTime.utc_now())
        )

      %{child: %{id: id2}, parent: %{data_structure_id: parent_id2}} =
        insert(:data_structure_relation,
          relation_type_id: RelationTypes.default_id!(),
          child: build(:data_structure_version, data_structure_id: id, version: version + 1)
        )

      Hierarchy.update_hierarchy([id1, id2])

      assert %{id: ^id1, path: path} = DataStructures.get_data_structure_version!(id, version, [])
      assert [%{"data_structure_id" => ^parent_id1}] = path

      assert %{id: ^id2, path: path} =
               DataStructures.get_data_structure_version!(id, version + 1, [])

      assert [%{"data_structure_id" => ^parent_id2}] = path
    end

    test "get_latest_version_by_external_id/2 obtains the latest version of a structure" do
      %{id: system_id} = insert(:system)
      external_id = "get_latest_version_by_external_id/2"
      ts = DateTime.utc_now()
      ds = insert(:data_structure, external_id: external_id, system_id: system_id)

      insert(:data_structure_version, data_structure_id: ds.id, version: 0, deleted_at: ts)
      insert(:data_structure_version, data_structure_id: ds.id, version: 1)
      v2 = insert(:data_structure_version, data_structure_id: ds.id, version: 2)
      v3 = insert(:data_structure_version, data_structure_id: ds.id, version: 3, deleted_at: ts)

      assert DataStructures.get_latest_version_by_external_id(external_id) <~> v3
      assert DataStructures.get_latest_version_by_external_id(external_id, deleted: false) <~> v2
    end

    test "get_data_structure_version!/2 with options: grants" do
      %{id: user_id, user_name: user_name} = CacheHelpers.insert_user()

      [dsv, parent, child] =
        ["structure", "parent", "child"]
        |> Enum.map(&insert(:data_structure, external_id: &1))
        |> Enum.map(&insert(:data_structure_version, data_structure_id: &1.id))

      [field | _] =
        fields =
        ["field1", "field2", "field3"]
        |> Enum.map(&insert(:data_structure, external_id: &1))
        |> Enum.map(&insert(:data_structure_version, data_structure_id: &1.id, class: "field"))

      relation_type_id = RelationTypes.default_id!()

      Enum.map(
        fields,
        &insert(:data_structure_relation,
          parent_id: child.id,
          child_id: &1.id,
          relation_type_id: relation_type_id
        )
      )

      insert(:data_structure_relation,
        parent_id: parent.id,
        child_id: dsv.id,
        relation_type_id: relation_type_id
      )

      insert(:data_structure_relation,
        parent_id: dsv.id,
        child_id: child.id,
        relation_type_id: relation_type_id
      )

      Hierarchy.update_hierarchy([dsv.id, parent.id])

      start_date = Date.utc_today() |> Date.add(-1)
      end_date = Date.utc_today() |> Date.add(2)

      %{id: grant_id1, detail: detail1} =
        insert(:grant,
          data_structure_id: parent.data_structure_id,
          user_id: user_id,
          start_date: start_date,
          end_date: end_date
        )

      %{id: grant_id2, detail: detail2} =
        insert(:grant,
          data_structure_id: dsv.data_structure_id,
          detail: %{"bar" => "baz"},
          user_id: user_id,
          start_date: start_date,
          end_date: end_date
        )

      %{id: grant_id3, detail: detail3} =
        insert(:grant,
          data_structure_id: field.data_structure_id,
          detail: %{"xyz" => "x"},
          user_id: user_id,
          start_date: start_date,
          end_date: end_date
        )

      start_date = Date.utc_today() |> Date.add(-3)
      end_date = Date.utc_today() |> Date.add(-2)

      insert(:grant,
        data_structure_id: field.data_structure_id,
        detail: %{"xyz" => "y"},
        user_id: user_id,
        start_date: start_date,
        end_date: end_date
      )

      assert %DataStructureVersion{
               grants: [
                 %{
                   id: ^grant_id1,
                   detail: ^detail1,
                   user: %{id: ^user_id, user_name: ^user_name}
                 },
                 %{
                   id: ^grant_id2,
                   detail: ^detail2,
                   user: %{id: ^user_id, user_name: ^user_name}
                 },
                 %{
                   id: ^grant_id3,
                   detail: ^detail3,
                   user: %{id: ^user_id, user_name: ^user_name}
                 }
               ]
             } = DataStructures.get_data_structure_version!(field.id, [:grants])
    end

    test "get_data_structure_version!/2 with options: grants and grant" do
      %{id: user_id} = CacheHelpers.insert_user()

      [dsv, parent] =
        ["structure", "parent"]
        |> Enum.map(&insert(:data_structure, external_id: &1))
        |> Enum.map(&insert(:data_structure_version, data_structure_id: &1.id))

      relation_type_id = RelationTypes.default_id!()

      insert(:data_structure_relation,
        parent_id: parent.id,
        child_id: dsv.id,
        relation_type_id: relation_type_id
      )

      Hierarchy.update_hierarchy([dsv.id, parent.id])

      start_date = Date.utc_today() |> Date.add(-1)
      end_date = Date.utc_today() |> Date.add(2)

      %{id: grant_id, detail: detail} =
        insert(:grant,
          data_structure_id: parent.data_structure_id,
          user_id: user_id,
          start_date: start_date,
          end_date: end_date
        )

      assert %DataStructureVersion{
               grants: [%{id: ^grant_id, detail: ^detail}],
               grant: %{id: ^grant_id, detail: ^detail}
             } =
               DataStructures.get_data_structure_version!(dsv.id, [
                 :grants,
                 :grant,
                 user_id: user_id
               ])
    end

    test "get_data_structure_version!/2 with options: grant" do
      %{id: user_id} = CacheHelpers.insert_user()

      [dsv, parent] =
        ["structure", "parent"]
        |> Enum.map(&insert(:data_structure, external_id: &1))
        |> Enum.map(&insert(:data_structure_version, data_structure_id: &1.id))

      relation_type_id = RelationTypes.default_id!()

      insert(:data_structure_relation,
        parent_id: parent.id,
        child_id: dsv.id,
        relation_type_id: relation_type_id
      )

      Hierarchy.update_hierarchy([dsv.id, parent.id])

      start_date = Date.utc_today() |> Date.add(-1)
      end_date = Date.utc_today() |> Date.add(2)

      %{id: grant_id, detail: detail} =
        insert(:grant,
          data_structure_id: parent.data_structure_id,
          user_id: user_id,
          start_date: start_date,
          end_date: end_date
        )

      assert %DataStructureVersion{
               grant: %{id: ^grant_id, detail: ^detail}
             } =
               DataStructures.get_data_structure_version!(dsv.id, [
                 :grant,
                 user_id: user_id
               ])
    end

    test "get_ancestors/2 obtains all ancestors of a data structure version" do
      [child | ancestors] =
        ["foo", "bar", "baz", "xyzzy"]
        |> create_hierarchy()
        |> Enum.reverse()

      assert DataStructures.get_ancestors(child) <~> ancestors
    end

    test "get_descendents/2 obtains all descendents of a data structure version" do
      [parent | descendents] =
        ["foo", "bar", "baz", "xyzzy"]
        |> create_hierarchy()

      assert DataStructures.get_descendents(parent) <~> descendents
    end
  end

  describe "structure_metadata" do
    @valid_attrs %{fields: %{}, data_structure_id: 0, version: 0}
    @update_attrs %{fields: %{"foo" => "bar"}, version: 0}
    @invalid_attrs %{fields: nil, data_structure_id: nil, version: nil}

    defp structure_metadata_fixture do
      ds = insert(:data_structure)
      attrs = Map.put(@valid_attrs, :data_structure_id, ds.id)
      {:ok, structure_metadata} = DataStructures.create_structure_metadata(attrs)

      structure_metadata
    end

    test "get_structure_metadata!/1 gets the metadata" do
      structure_metadata = structure_metadata_fixture()

      assert structure_metadata.id ==
               DataStructures.get_structure_metadata!(structure_metadata.id).id
    end

    test "create_structure_metadata/1 with valid attrs creates the metadata", %{
      data_structure: ds
    } do
      attrs = Map.put(@valid_attrs, :data_structure_id, ds.id)

      assert {:ok, %StructureMetadata{fields: fields, data_structure_id: ds_id, version: version}} =
               DataStructures.create_structure_metadata(attrs)

      assert ds.id == ds_id
      assert attrs.fields == fields
      assert attrs.version == version
    end

    test "create_structure_metadata/1 with invalid attrs returns an error" do
      assert {:error, %Ecto.Changeset{}} =
               DataStructures.create_structure_metadata(@invalid_attrs)
    end

    test "update_structure_metadata/1 with valid attrs updates the metadata", %{
      data_structure: ds
    } do
      mm = insert(:structure_metadata, data_structure: ds)

      assert {:ok, %StructureMetadata{fields: fields, data_structure_id: ds_id, version: version}} =
               DataStructures.update_structure_metadata(mm, @update_attrs)

      assert ds.id == ds_id
      assert @update_attrs.fields == fields
      assert @update_attrs.version == version
    end
  end

  describe "profile_source/1" do
    setup do
      s1 = insert(:source, config: %{"job_types" => ["catalog", "quality", "profile"]})
      s2 = insert(:source)

      s3 =
        insert(:source,
          external_id: "foo",
          config: %{"job_types" => ["catalog"], "alias" => "foo"}
        )

      s4 = insert(:source, config: %{"job_types" => ["profile"], "alias" => "foo"})

      v1 = insert(:data_structure_version, data_structure: insert(:data_structure, source: s1))
      v2 = insert(:data_structure_version, data_structure: insert(:data_structure, source: s2))
      v3 = insert(:data_structure_version, data_structure: insert(:data_structure, source: s3))

      [sources: [s1, s2, s3, s4], versions: [v1, v2, v3]]
    end

    test "profile_source/1 when there are not related sources with profile", %{
      versions: [_, v, _]
    } do
      assert %{profile_source: nil} = DataStructures.profile_source(v)
    end

    test "profile_source/1 get profile source when is directly related to the data structure", %{
      versions: [v, _, _],
      sources: [%{external_id: external_id}, _, _, _]
    } do
      assert %{profile_source: %{external_id: ^external_id}} = DataStructures.profile_source(v)
    end

    test "profile_source/1 get profile source when is related to the data structure by source alias",
         %{
           versions: [_, _, v],
           sources: [_, _, s3, s4]
         } do
      %{external_id: s3_external_id} = s3
      %{external_id: s4_external_id} = s4

      assert %{
               data_structure: %{source: %{external_id: ^s3_external_id}},
               profile_source: %{external_id: ^s4_external_id}
             } = DataStructures.profile_source(v)
    end
  end

  describe "get_field_structures/2" do
    test "generates a valid query" do
      %{parent: parent} = create_relation()
      assert [_] = DataStructures.get_field_structures(parent, with_confidential: false)
    end
  end

  describe "get_children/2" do
    test "generates a valid query" do
      %{parent: parent} = create_relation()
      assert [_] = DataStructures.get_children(parent, with_confidential: false)
      assert [] = DataStructures.get_children(parent, with_confidential: false, default: false)
    end

    test "finds non-default relation" do
      %{parent: parent} = insert(:data_structure_relation)

      assert [_] = DataStructures.get_children(parent, default: false)
      assert [] = DataStructures.get_children(parent)
    end
  end

  describe "get_parents/2" do
    test "generates a valid query" do
      %{child: child} = create_relation()
      assert [_] = DataStructures.get_parents(child, with_confidential: false)
      assert [] = DataStructures.get_parents(child, with_confidential: false, default: false)
    end

    test "finds non-default relation" do
      %{child: child} = insert(:data_structure_relation)

      assert [_] = DataStructures.get_parents(child, default: false)
      assert [] = DataStructures.get_parents(child)
    end
  end

  describe "get_siblings/2" do
    test "generates a valid query" do
      %{parent_id: parent_id, child: child, relation_type_id: type_id} = create_relation()

      insert(:data_structure_relation,
        relation_type_id: type_id,
        parent_id: parent_id,
        child: build(:data_structure_version)
      )

      assert [_, _] = DataStructures.get_siblings(child, with_confidential: false)
      assert [] = DataStructures.get_siblings(child, with_confidential: false, default: false)
    end
  end

  describe "grant request reindex" do
    test "grant request reindex on data structure metadata update",
         %{
           data_structure: data_structure
         } do
      mm = insert(:structure_metadata, data_structure: data_structure)

      %{id: grant_request_id1} =
        insert(:grant_request,
          data_structure: data_structure
        )

      %{id: grant_request_id2} =
        insert(:grant_request,
          data_structure: data_structure
        )

      assert {:ok, _} = DataStructures.update_structure_metadata(mm, @update_attrs)

      assert {:reindex, :grant_requests, [^grant_request_id1, ^grant_request_id2]} =
               Enum.find(IndexWorkerMock.calls(), fn {action, index, _} ->
                 action == :reindex and index == :grant_requests
               end)
    end

    test "grant request reindex when applies changes to descendents", %{claims: claims} do
      %{data_structure: parent_data_structure, id: parent_id} = insert(:data_structure_version)
      %{data_structure: child_data_structure, id: child_id} = insert(:data_structure_version)

      insert(:data_structure_relation,
        parent_id: parent_id,
        child_id: child_id,
        relation_type_id: RelationTypes.default_id!()
      )

      insert(:grant_request,
        data_structure: parent_data_structure
      )

      insert(:grant_request,
        data_structure: child_data_structure
      )

      params = %{domain_ids: [2, 3]}

      assert {:ok, _} =
               DataStructures.update_data_structure(claims, parent_data_structure, params, true)

      assert {:reindex, :grant_requests, [_, _]} =
               Enum.find(IndexWorkerMock.calls(), fn {action, index, _} ->
                 action == :reindex and index == :grant_requests
               end)
    end

    test "reindex grant request if updated domain_ids and has implementation_structure relation",
         %{
           data_structure: %{id: id} = data_structure,
           claims: claims
         } do
      %{id: implementation_id} = insert(:implementation, version: 1, status: :published)

      insert(:implementation_structure,
        data_structure_id: id,
        implementation_id: implementation_id
      )

      %{id: grant_request_id} =
        insert(:grant_request,
          data_structure: data_structure
        )

      params = %{domain_ids: [1, 2, 3]}

      assert {:ok, _} =
               DataStructures.update_data_structure(claims, data_structure, params, false)

      assert {:reindex, :grant_requests, [^grant_request_id]} =
               Enum.find(IndexWorkerMock.calls(), fn {action, index, _} ->
                 action == :reindex and index == :grant_requests
               end)
    end

    test "reindex grants when updates confidential and domain_ids", %{
      data_structure: data_structure,
      claims: claims
    } do
      params = %{confidential: true, domain_ids: [1, 2, 3]}

      %{id: grant_request_id} =
        insert(:grant_request,
          data_structure: data_structure
        )

      assert {:ok, _} =
               DataStructures.update_data_structure(claims, data_structure, params, false)

      assert {:reindex, :grant_requests, [^grant_request_id]} =
               Enum.find(IndexWorkerMock.calls(), fn {action, index, _} ->
                 action == :reindex and index == :grant_requests
               end)
    end
  end

  defp create_relation do
    insert(:data_structure_relation,
      relation_type_id: RelationTypes.default_id!(),
      parent: build(:data_structure_version),
      child:
        build(
          :data_structure_version,
          class: "field",
          data_structure: build(:data_structure, confidential: false)
        )
    )
  end

  defp create_hierarchy_with_protected_metadata do
    metadata = %{
      "m_foo" => "m_bar",
      DataStructures.protected() => %{
        "m_field1" => "m_field1",
        "m_field2" => "m_field2"
      }
    }

    mutable_metadata = %{
      "mm_foo" => "mm_bar",
      DataStructures.protected() => %{
        "mm_field1" => "mm_field1",
        "mm_field2" => "mm_field2"
      }
    }

    data_structures =
      Enum.map(
        ["structure", "parent", "child", "sibling"],
        &insert(:data_structure, external_id: &1)
      )

    _inserted_mutable_metadata =
      Enum.map(
        data_structures,
        &insert(
          :structure_metadata,
          data_structure_id: &1.id,
          fields: mutable_metadata
        )
      )

    [dsv, parent, child, sibling] =
      Enum.map(
        data_structures,
        &insert(:data_structure_version, data_structure_id: &1.id, metadata: metadata)
      )

    relation_type_id = RelationTypes.default_id!()

    insert(:data_structure_relation,
      parent_id: parent.id,
      child_id: dsv.id,
      relation_type_id: relation_type_id
    )

    insert(:data_structure_relation,
      parent_id: parent.id,
      child_id: sibling.id,
      relation_type_id: relation_type_id
    )

    insert(:data_structure_relation,
      parent_id: dsv.id,
      child_id: child.id,
      relation_type_id: relation_type_id
    )

    %{
      dsv: dsv,
      parent_dsv: parent,
      child_dsv: child,
      sibling_dsv: sibling,
      metadata: metadata,
      mutable_metadata: mutable_metadata
    }
  end
end
