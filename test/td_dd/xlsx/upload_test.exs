defmodule TdDd.XLSX.UploadTest do
  use TdDd.DataCase

  import Mox

  alias TdCore.Search.IndexWorkerMock
  alias TdDd.DataStructures.DataStructureVersions.Workers.EmbeddingsUpsertBatch
  alias TdDd.DataStructures.FileBulkUpdateEvent
  alias TdDd.Search.StructureEnricher
  alias TdDd.XLSX.Jobs.UploadWorker
  alias TdDd.XLSX.Upload

  @moduletag sandbox: :shared

  @content_for_type_1 [
    %{
      "name" => "group",
      "fields" => [
        %{
          "cardinality" => "?",
          "label" => "Text",
          "name" => "text",
          "type" => "string",
          "widget" => "string"
        },
        %{
          "cardinality" => "1",
          "default" => %{"value" => "", "origin" => "default"},
          "description" => "description",
          "label" => "critical term",
          "name" => "critical",
          "type" => "string",
          "values" => %{
            "fixed" => ["Yes", "No"]
          }
        },
        %{
          "cardinality" => "?",
          "label" => "Numeric",
          "name" => "integer",
          "type" => "integer",
          "values" => nil,
          "widget" => "number"
        },
        %{
          "cardinality" => "?",
          "label" => "Texto Enriquecido",
          "name" => "enriched_text",
          "type" => "enriched_text",
          "widget" => "enriched_text"
        },
        %{
          "cardinality" => "*",
          "label" => "Urls One Or None",
          "name" => "urls_one_or_none",
          "type" => "url",
          "values" => nil,
          "widget" => "pair_list"
        }
      ]
    }
  ]

  @content_for_type_2 [
    %{
      "name" => "group",
      "fields" => [
        %{
          "cardinality" => "+",
          "description" => "description",
          "label" => "Role",
          "name" => "role",
          "type" => "user",
          "values" => %{"role_users" => "Data Owner"}
        },
        %{
          "cardinality" => "?",
          "label" => "Numeric",
          "name" => "integer",
          "type" => "integer",
          "values" => nil,
          "widget" => "number"
        },
        %{
          "cardinality" => "*",
          "label" => "Clave valor",
          "name" => "key_value",
          "type" => "string",
          "values" => %{
            "fixed_tuple" => [
              %{"text" => "Elemento 1", "value" => "1"},
              %{"text" => "Elemento 2", "value" => "2"},
              %{"text" => "Elemento 3", "value" => "3"},
              %{"text" => "Elemento 4", "value" => "4"}
            ]
          },
          "widget" => "dropdown"
        },
        %{
          "cardinality" => "?",
          "name" => "hierarchy_name_1",
          "label" => "Hierarchy name 1",
          "type" => "hierarchy",
          "values" => %{"hierarchy" => %{"id" => 1}},
          "widget" => "dropdown"
        },
        %{
          "cardinality" => "*",
          "name" => "hierarchy_name_2",
          "label" => "Hierarchy name 2",
          "type" => "hierarchy",
          "values" => %{"hierarchy" => %{"id" => 1}},
          "widget" => "dropdown"
        }
      ]
    }
  ]

  @content_for_type_3 [
    %{
      "name" => "group",
      "fields" => [
        %{
          "cardinality" => "?",
          "label" => "label_i18n_test.Dropdown Fixed",
          "name" => "i18n_test.dropdown.fixed",
          "type" => "string",
          "values" => %{"fixed" => ["pear", "banana", "apple", "peach"]},
          "widget" => "dropdown"
        },
        %{
          "cardinality" => "?",
          "label" => "label_i18n_test_no_translate",
          "name" => "i18n_test_no_translate",
          "type" => "string",
          "values" => nil,
          "widget" => "string"
        },
        %{
          "cardinality" => "?",
          "label" => "label_i18n_test.Radio Fixed",
          "name" => "i18n_test.radio.fixed",
          "type" => "string",
          "values" => %{"fixed" => ["pear", "banana", "apple", "peach"]},
          "widget" => "radio"
        },
        %{
          "cardinality" => "*",
          "label" => "label_i18n_test.Checkbox Fixed",
          "name" => "i18n_test.checkbox.fixed",
          "type" => "string",
          "values" => %{"fixed" => ["pear", "banana", "apple", "peach"]},
          "widget" => "checkbox"
        }
      ]
    }
  ]

  @content_for_type_4 [
    %{
      "name" => "group",
      "fields" => [
        %{
          "cardinality" => "?",
          "label" => "String Field",
          "name" => "string_field",
          "type" => "string",
          "widget" => "string"
        },
        %{
          "name" => "table_field",
          "type" => "table",
          "label" => "Table Field",
          "cardinality" => "*",
          "values" => %{
            "table_columns" => [
              %{"mandatory" => true, "name" => "First Column"},
              %{"mandatory" => false, "name" => "Second Column"}
            ]
          }
        }
      ]
    }
  ]

  @content_for_type_5 [
    %{
      "fields" => [
        %{
          "cardinality" => "?",
          "default" => %{"origin" => "default", "value" => ""},
          "label" => "Level 1",
          "name" => "Level 1",
          "subscribable" => false,
          "type" => "string",
          "values" => %{"fixed" => ["A", "B", "C"]},
          "widget" => "dropdown"
        },
        %{
          "ai_suggestion" => false,
          "cardinality" => "?",
          "default" => %{"origin" => "default", "value" => ""},
          "label" => "Level 2",
          "name" => "Level 2",
          "subscribable" => false,
          "type" => "string",
          "values" => %{
            "switch" => %{
              "on" => "Level 1",
              "values" => %{
                "" => [],
                "A" => ["A1", "A2"],
                "B" => ["B1", "B2"],
                "C" => ["C1", "C2"]
              }
            }
          },
          "widget" => "dropdown"
        }
      ],
      "name" => "Other information"
    }
  ]

  setup_all do
    start_supervised({Task.Supervisor, name: TdDd.TaskSupervisor})
    :ok
  end

  setup :set_mox_from_context

  setup do
    stub(MockClusterHandler, :call, fn :ai, TdAi.Indices, :exists_enabled?, [] -> {:ok, true} end)
    :ok
  end

  describe "TdDd.XLSX.Upload.structures/2" do
    setup do
      IndexWorkerMock.clear()
      start_supervised!(StructureEnricher)

      on_exit(fn -> IndexWorkerMock.clear() end)

      hierarchy =
        %{
          id: 1,
          name: "name_1",
          nodes: [
            build(:hierarchy_node, %{
              node_id: 1,
              parent_id: nil,
              name: "father",
              path: "/father",
              hierarchy_id: 1
            }),
            build(:hierarchy_node, %{
              node_id: 2,
              parent_id: 1,
              name: "children_1",
              path: "/father/children_1",
              hierarchy_id: 1
            }),
            build(:hierarchy_node, %{
              node_id: 3,
              parent_id: 1,
              name: "children_2",
              path: "/father/children_2",
              hierarchy_id: 1
            }),
            build(:hierarchy_node, %{
              node_id: 4,
              parent_id: nil,
              name: "children_2",
              path: "/children_2",
              hierarchy_id: 1
            })
          ]
        }

      hierarchy = CacheHelpers.insert_hierarchy(hierarchy)

      %{id: id_t1, name: type1} =
        CacheHelpers.insert_template(content: @content_for_type_1, type: "type_1", name: "type_1")

      %{id: id_t2, name: type2} =
        CacheHelpers.insert_template(content: @content_for_type_2, type: "type_2", name: "type_2")

      %{id: id_t3, name: type3} =
        CacheHelpers.insert_template(content: @content_for_type_3, type: "type_3", name: "type_3")

      domain = CacheHelpers.insert_domain()

      insert(:data_structure_type, name: type1, template_id: id_t1)
      insert(:data_structure_type, name: type2, template_id: id_t2)
      insert(:data_structure_type, name: type3, template_id: id_t3)

      structures_type_1 =
        Enum.map(1..10, fn id ->
          data_structure =
            insert(:data_structure, external_id: "ex_id#{id}", domain_ids: [domain.id])

          valid_structure_note(type1, data_structure,
            df_content: %{
              "text" => %{"value" => "foo", "origin" => "user"},
              "critical" => %{"value" => "No", "origin" => "user"},
              "urls_one_or_none" => %{
                "value" => [%{"url_name" => "", "url_value" => "https://foo.bar"}],
                "origin" => "user"
              }
            }
          )
        end)

      structures_type_2 =
        Enum.map(11..20, fn id ->
          data_structure =
            insert(:data_structure, external_id: "ex_id#{id}", domain_ids: [domain.id])

          opts = if Integer.mod(id, 2) !== 0, do: [], else: [status: :draft]
          valid_structure_note(type2, data_structure, opts)
        end)

      _structures_type_3 =
        Enum.map(21..22, fn id ->
          data_structure =
            insert(:data_structure, external_id: "ex_id#{id}", domain_ids: [domain.id])

          valid_structure_note(type3, data_structure, df_content: %{})
        end)

      user_ids =
        Enum.map(["Role", "Role 1", "Role 2"], fn full_name ->
          CacheHelpers.insert_user(full_name: full_name).id
        end)

      %{data_structure: %{domain_ids: [domain_id]}} = List.first(structures_type_1)
      CacheHelpers.insert_acl(domain_id, "Data Owner", user_ids)
      claims = build(:claims, role: "user")

      [
        structures: structures_type_1 ++ structures_type_2,
        hierarchy: hierarchy,
        claims: claims,
        domain: domain,
        template_ids: [id_t1, id_t2, id_t3]
      ]
    end

    test "uploads structures", %{
      hierarchy: hierarchy,
      claims: %{user_id: user_id} = claims,
      domain: %{id: domain_id}
    } do
      CacheHelpers.put_session_permissions(claims, %{
        create_structure_note: [domain_id],
        publish_structure_note_from_draft: [domain_id],
        edit_structure_note: [domain_id],
        view_data_structure: [domain_id]
      })

      {:ok,
       %{
         update_notes: update_notes,
         split_duplicates: {_contents, duplicate_errors},
         external_id_errors: external_id_errors
       }} =
        Upload.structures(
          %{path: "test/fixtures/xlsx/upload.xlsx", file_name: "upload.xlsx", hash: "hash"},
          user_id: user_id,
          claims: claims,
          task_reference: "oban:1"
        )

      updated_structure_ids = Map.keys(update_notes)

      assert external_id_errors == [
               %{
                 message: "external_id_not_found",
                 external_id: "ex_id15_invalid",
                 row: 6,
                 sheet: "type_2"
               },
               %{
                 message: "external_id_not_found",
                 external_id: "ex_id9_invalid",
                 row: 10,
                 sheet: "type_1"
               }
             ]

      assert duplicate_errors == [
               %{message: "duplicate", external_id: "ex_id3", row: 12, sheet: "type_1"},
               %{message: "duplicate", external_id: "ex_id2", row: 9, sheet: "type_1"}
             ]

      {_id, note} =
        Enum.find(update_notes, fn {_id, %{data_structure: data_structure}} ->
          data_structure.external_id == "ex_id1"
        end)

      assert note.df_content == %{
               "critical" => %{"origin" => "file", "value" => "Yes"},
               "text" => %{"origin" => "file", "value" => "text"},
               "urls_one_or_none" => %{
                 "origin" => "file",
                 "value" => [%{"url_name" => "", "url_value" => ""}]
               },
               "enriched_text" => %{"origin" => "file", "value" => %{}}
             }

      {_id, note} =
        Enum.find(update_notes, fn {_id, %{data_structure: data_structure}} ->
          data_structure.external_id == "ex_id2"
        end)

      assert note.df_content == %{
               "critical" => %{"origin" => "file", "value" => "Yes"},
               "text" => %{"origin" => "file", "value" => "text2"},
               "urls_one_or_none" => %{
                 "origin" => "file",
                 "value" => [%{"url_name" => "", "url_value" => ""}]
               },
               "enriched_text" => %{"origin" => "file", "value" => %{}}
             }

      {_id, note} =
        Enum.find(update_notes, fn {_id, %{data_structure: data_structure}} ->
          data_structure.external_id == "ex_id3"
        end)

      assert note.df_content == %{
               "critical" => %{"origin" => "file", "value" => "No"},
               "text" => %{"origin" => "file", "value" => ""},
               "urls_one_or_none" => %{
                 "origin" => "file",
                 "value" => [%{"url_name" => "", "url_value" => ""}]
               },
               "enriched_text" => %{"origin" => "file", "value" => %{}}
             }

      {_id, note} =
        Enum.find(update_notes, fn {_id, %{data_structure: data_structure}} ->
          data_structure.external_id == "ex_id4"
        end)

      assert note.df_content == %{
               "critical" => %{"origin" => "file", "value" => "No"},
               "text" => %{"origin" => "file", "value" => ""},
               "urls_one_or_none" => %{
                 "origin" => "file",
                 "value" => [%{"url_name" => "", "url_value" => ""}]
               },
               "enriched_text" => %{"origin" => "file", "value" => %{}}
             }

      assert {_id, {:error, {changeset, data_structure}}} =
               Enum.find(update_notes, fn
                 {_id, %{data_structure: _data_structure}} ->
                   false

                 {_id, {:error, {_changeset, data_structure}}} ->
                   data_structure.external_id == "ex_id6"
               end)

      assert changeset.changes.df_content == %{
               "critical" => %{"origin" => "file", "value" => ""},
               "enriched_text" => %{
                 "origin" => "file",
                 "value" => %{
                   "document" => %{
                     "nodes" => [
                       %{
                         "nodes" => [
                           %{"leaves" => [%{"text" => "I'm 6"}], "object" => "text"}
                         ],
                         "object" => "block",
                         "type" => "paragraph"
                       }
                     ]
                   }
                 }
               },
               "text" => %{"origin" => "file", "value" => ""},
               "urls_one_or_none" => %{
                 "origin" => "file",
                 "value" => [%{"url_name" => "", "url_value" => ""}]
               }
             }

      assert changeset.errors[:df_content] ==
               {"critical: can't be blank",
                [critical: {"can't be blank", [validation: :required]}]}

      refute changeset.valid?
      assert data_structure.row == %{index: 5, sheet: "type_1"}

      assert {_id, {:error, {changeset, data_structure}}} =
               Enum.find(update_notes, fn
                 {_id, %{data_structure: _data_structure}} ->
                   false

                 {_id, {:error, {_changeset, data_structure}}} ->
                   data_structure.external_id == "ex_id7"
               end)

      assert changeset.changes.df_content == %{
               "critical" => %{"origin" => "file", "value" => ""},
               "enriched_text" => %{
                 "origin" => "file",
                 "value" => %{
                   "document" => %{
                     "nodes" => [
                       %{
                         "nodes" => [
                           %{"leaves" => [%{"text" => "Enriched text"}], "object" => "text"}
                         ],
                         "object" => "block",
                         "type" => "paragraph"
                       }
                     ]
                   }
                 }
               },
               "text" => %{"origin" => "file", "value" => ""},
               "urls_one_or_none" => %{
                 "origin" => "file",
                 "value" => [%{"url_name" => "", "url_value" => "https://www.google.es"}]
               }
             }

      assert changeset.errors[:df_content] ==
               {"critical: can't be blank",
                [critical: {"can't be blank", [validation: :required]}]}

      refute changeset.valid?
      assert data_structure.row == %{index: 6, sheet: "type_1"}

      assert {_id, {:error, {changeset, data_structure}}} =
               Enum.find(update_notes, fn
                 {_id, %{data_structure: _data_structure}} ->
                   false

                 {_id, {:error, {_changeset, data_structure}}} ->
                   data_structure.external_id == "ex_id10"
               end)

      assert changeset.changes.df_content == %{
               "critical" => %{"origin" => "file", "value" => ""},
               "enriched_text" => %{"origin" => "file", "value" => %{}},
               "text" => %{"origin" => "file", "value" => ""},
               "urls_one_or_none" => %{
                 "origin" => "file",
                 "value" => [%{"url_name" => "", "url_value" => ""}]
               }
             }

      assert changeset.errors[:df_content] ==
               {"critical: can't be blank",
                [critical: {"can't be blank", [validation: :required]}]}

      refute changeset.valid?
      assert data_structure.row == %{index: 11, sheet: "type_1"}

      {_id, note} =
        Enum.find(update_notes, fn
          {_id, %{data_structure: data_structure}} ->
            data_structure.external_id == "ex_id11"

          {_id, {:error, {_changeset, data_structure}}} ->
            data_structure.external_id == "ex_id11"
        end)

      assert note.df_content == %{
               "hierarchy_name_1" => %{"origin" => "file", "value" => ""},
               "hierarchy_name_2" => %{"origin" => "file", "value" => []},
               "integer" => %{"origin" => "file", "value" => nil},
               "key_value" => %{"origin" => "file", "value" => [""]},
               "role" => %{"origin" => "file", "value" => ["Role", "Role 1"]}
             }

      {_id, {:error, {changeset, data_structure}}} =
        Enum.find(update_notes, fn
          {_id, %{data_structure: data_structure}} ->
            data_structure.external_id == "ex_id16"

          {_id, {:error, {_changeset, data_structure}}} ->
            data_structure.external_id == "ex_id16"
        end)

      assert changeset.changes.df_content == %{
               "hierarchy_name_1" => %{"origin" => "file", "value" => ""},
               "hierarchy_name_2" => %{"origin" => "file", "value" => []},
               "integer" => %{"origin" => "file", "value" => 2},
               "key_value" => %{"origin" => "file", "value" => [""]},
               "role" => %{"origin" => "file", "value" => ["Miss This"]}
             }

      assert {"role: has an invalid entry", fields} = changeset.errors[:df_content]
      assert {"has an invalid entry", [validation: :subset, enum: enum]} = fields[:role]
      assert Enum.all?(enum, fn role -> role in ["Role", "Role 1", "Role 2"] end)

      refute changeset.valid?
      assert data_structure.row == %{index: 7, sheet: "type_2"}

      {_id, note} =
        Enum.find(update_notes, fn
          {_id, %{data_structure: data_structure}} ->
            data_structure.external_id == "ex_id18"

          {_id, {:error, {_changeset, data_structure}}} ->
            data_structure.external_id == "ex_id18"
        end)

      assert note.df_content == %{
               "hierarchy_name_1" => %{"origin" => "file", "value" => ""},
               "hierarchy_name_2" => %{"origin" => "file", "value" => []},
               "integer" => %{"origin" => "file", "value" => nil},
               "key_value" => %{"origin" => "file", "value" => ["2"]},
               "role" => %{"origin" => "file", "value" => ["Role 2"]}
             }

      {_id, {:error, {changeset, data_structure}}} =
        Enum.find(update_notes, fn
          {_id, %{data_structure: data_structure}} ->
            data_structure.external_id == "ex_id20"

          {_id, {:error, {_changeset, data_structure}}} ->
            data_structure.external_id == "ex_id20"
        end)

      children_1 = Enum.find(hierarchy.nodes, fn %{name: name} -> name == "children_1" end)
      father = Enum.find(hierarchy.nodes, fn %{name: name} -> name == "father" end)

      assert changeset.changes.df_content == %{
               "hierarchy_name_1" => %{"origin" => "file", "value" => children_1.key},
               "hierarchy_name_2" => %{
                 "origin" => "file",
                 "value" => [children_1.key, father.key]
               },
               "integer" => %{"origin" => "file", "value" => nil},
               "key_value" => %{"origin" => "file", "value" => [""]},
               "role" => %{"origin" => "file", "value" => []}
             }

      assert data_structure.row == %{index: 11, sheet: "type_2"}

      assert [{:reindex, :structures, indexed_structures}] = IndexWorkerMock.calls()

      assert jobs = all_enqueued(worker: EmbeddingsUpsertBatch)
      assert Enum.count(jobs) == 1
      assert MapSet.equal?(MapSet.new(indexed_structures), MapSet.new(updated_structure_ids))
      assert jobs = all_enqueued(worker: EmbeddingsUpsertBatch)
      assert Enum.count(jobs) == 1

      assert [
               %{
                 response: %{"errors" => [_ | _], "ids" => [_ | _]},
                 status: "COMPLETED",
                 task_reference: "oban:1"
               }
             ] =
               Repo.all(FileBulkUpdateEvent)
    end

    test "returns error when external id is not found" do
      assert {:error, %{message: :external_id_not_found}} =
               Upload.structures(
                 %{
                   path: "test/fixtures/xlsx/upload_empty_external_id.xlsx",
                   file_name: "upload_empty_external_id.xlsx",
                   hash: "hash"
                 },
                 user_id: 0,
                 task_reference: "oban:1"
               )

      assert [event] = Repo.all(FileBulkUpdateEvent)

      assert Map.take(event, [:user_id, :status, :hash, :filename, :message, :task_reference]) ==
               %{
                 user_id: 0,
                 status: "FAILED",
                 hash: "hash",
                 filename: "upload_empty_external_id.xlsx",
                 message: "external_id_not_found",
                 task_reference: "oban:1"
               }
    end

    test "returns error when template is not found", %{template_ids: [id | _]} do
      CacheHelpers.delete_template(id)

      assert {:error, :template_not_found} =
               Upload.structures(
                 %{
                   path: "test/fixtures/xlsx/upload.xlsx",
                   file_name: "upload.xlsx",
                   hash: "hash"
                 },
                 user_id: 0,
                 task_reference: "oban:1"
               )

      assert [event] = Repo.all(FileBulkUpdateEvent)

      assert Map.take(event, [:user_id, :status, :hash, :filename, :message, :task_reference]) ==
               %{
                 user_id: 0,
                 status: "FAILED",
                 hash: "hash",
                 filename: "upload.xlsx",
                 message: "template_not_found",
                 task_reference: "oban:1"
               }
    end

    test "returns forbidden when user has not permissions", %{
      claims: %{user_id: user_id} = claims
    } do
      params = %{path: "test/fixtures/xlsx/upload.xlsx", file_name: "upload.xlsx", hash: "hash"}

      {:cancel, :forbidden} =
        Upload.structures(params, user_id: user_id, claims: claims, task_reference: "oban:1")

      assert [event] = Repo.all(FileBulkUpdateEvent)

      assert Map.take(event, [:user_id, :status, :hash, :filename, :message, :task_reference]) ==
               %{
                 user_id: user_id,
                 status: "FAILED",
                 hash: "hash",
                 filename: "upload.xlsx",
                 message: "forbidden",
                 task_reference: "oban:1"
               }
    end

    test "removes empty fields", %{
      claims: %{user_id: user_id} = claims,
      domain: %{id: domain_id},
      structures: structures
    } do
      CacheHelpers.put_session_permissions(claims, %{
        create_structure_note: [domain_id],
        publish_structure_note_from_draft: [domain_id],
        edit_structure_note: [domain_id],
        view_data_structure: [domain_id]
      })

      {:ok, %{update_notes: update_notes}} =
        Upload.structures(
          %{
            path: "test/fixtures/xlsx/upload_empty_fields.xlsx",
            file_name: "upload_empty_fields.xlsx",
            hash: "hash"
          },
          user_id: user_id,
          claims: claims,
          task_reference: "oban:1"
        )

      assert {_id, {:error, {changeset, _data_structure}}} =
               Enum.find(update_notes, fn
                 {_id, %{data_structure: _data_structure}} ->
                   false

                 {_id, {:error, {_changeset, data_structure}}} ->
                   data_structure.external_id == "ex_id1"
               end)

      assert changeset.errors[:df_content] ==
               {"critical: can't be blank",
                [critical: {"can't be blank", [validation: :required]}]}

      source_note =
        Enum.find(structures, fn %{data_structure: %{external_id: external_id}} ->
          external_id == "ex_id2"
        end)

      assert source_note.df_content == %{
               "critical" => %{"origin" => "user", "value" => "No"},
               "text" => %{"origin" => "user", "value" => "foo"},
               "urls_one_or_none" => %{
                 "origin" => "user",
                 "value" => [%{"url_name" => "", "url_value" => "https://foo.bar"}]
               }
             }

      {_id, note} =
        Enum.find(update_notes, fn
          {_id, %{data_structure: data_structure}} ->
            data_structure.external_id == "ex_id2"

          {_id, {:error, {_changeset, data_structure}}} ->
            data_structure.external_id == "ex_id2"
        end)

      assert note.df_content == %{
               "critical" => %{"origin" => "file", "value" => "Yes"},
               "enriched_text" => %{"origin" => "file", "value" => %{}},
               "text" => %{"origin" => "file", "value" => ""},
               "urls_one_or_none" => %{
                 "origin" => "user",
                 "value" => [%{"url_name" => "", "url_value" => "https://foo.bar"}]
               }
             }

      assert [{:reindex, :structures, indexed_structures}] = IndexWorkerMock.calls()
      assert Enum.count(indexed_structures) == 2
      assert jobs = all_enqueued(worker: EmbeddingsUpsertBatch)
      assert Enum.count(jobs) == 1
      assert [job] = jobs
      assert Enum.count(job.args["data_structure_ids"]) == 2
    end

    test "removes empty fields when note is published", %{
      claims: %{user_id: user_id} = claims,
      domain: %{id: domain_id}
    } do
      CacheHelpers.put_session_permissions(claims, %{
        create_structure_note: [domain_id],
        publish_structure_note_from_draft: [domain_id],
        edit_structure_note: [domain_id],
        view_data_structure: [domain_id]
      })

      data_structure =
        insert(:data_structure, external_id: "ex_id23", domain_ids: [domain_id])

      valid_structure_note("type_1", data_structure,
        df_content: %{
          "text" => %{"value" => "foo", "origin" => "user"},
          "critical" => %{"value" => "No", "origin" => "user"},
          "urls_one_or_none" => %{
            "value" => [%{"url_name" => "", "url_value" => "https://foo.bar"}],
            "origin" => "user"
          }
        },
        status: "published"
      )

      {:ok, %{update_notes: update_notes}} =
        Upload.structures(
          %{
            path: "test/fixtures/xlsx/upload_empty_with_status.xlsx",
            file_name: "upload_empty_with_status.xlsx",
            hash: "hash"
          },
          user_id: user_id,
          claims: claims,
          task_reference: "oban:1"
        )

      {_id, note} =
        Enum.find(update_notes, fn
          {_id, %{data_structure: data_structure}} ->
            data_structure.external_id == "ex_id23"
        end)

      assert note.status == :draft

      assert note.df_content == %{
               "critical" => %{"origin" => "file", "value" => "Yes"},
               "enriched_text" => %{"origin" => "file", "value" => %{}},
               "text" => %{"origin" => "file", "value" => ""},
               "urls_one_or_none" => %{
                 "origin" => "user",
                 "value" => [%{"url_name" => "", "url_value" => "https://foo.bar"}]
               }
             }

      assert [{:reindex, :structures, indexed_structures}] = IndexWorkerMock.calls()
      assert Enum.count(indexed_structures) == 1
      assert jobs = all_enqueued(worker: EmbeddingsUpsertBatch)
      assert Enum.count(jobs) == 1
    end

    test "removes empty fields when note is published and auto publish = true", %{
      claims: %{user_id: user_id} = claims,
      domain: %{id: domain_id}
    } do
      CacheHelpers.put_session_permissions(claims, %{
        create_structure_note: [domain_id],
        publish_structure_note_from_draft: [domain_id],
        edit_structure_note: [domain_id],
        view_data_structure: [domain_id]
      })

      data_structure =
        insert(:data_structure, external_id: "ex_id23", domain_ids: [domain_id])

      valid_note =
        valid_structure_note("type_1", data_structure,
          df_content: %{
            "text" => %{"value" => "foo", "origin" => "user"},
            "critical" => %{"value" => "No", "origin" => "user"},
            "urls_one_or_none" => %{
              "value" => [%{"url_name" => "", "url_value" => "https://foo.bar"}],
              "origin" => "user"
            }
          },
          status: "published"
        )

      assert valid_note.version == 1

      {:ok, %{update_notes: update_notes}} =
        Upload.structures(
          %{
            path: "test/fixtures/xlsx/upload_empty_with_status.xlsx",
            file_name: "upload_empty_with_status.xlsx",
            hash: "hash"
          },
          user_id: user_id,
          claims: claims,
          task_reference: "oban:1",
          auto_publish: true
        )

      {_id, note} =
        Enum.find(update_notes, fn
          {_id, %{data_structure: data_structure}} ->
            data_structure.external_id == "ex_id23"
        end)

      assert note.version == 2
      assert note.status == :published

      assert note.df_content == %{
               "critical" => %{"origin" => "file", "value" => "Yes"},
               "enriched_text" => %{"origin" => "file", "value" => %{}},
               "text" => %{"origin" => "file", "value" => ""},
               "urls_one_or_none" => %{
                 "origin" => "user",
                 "value" => [%{"url_name" => "", "url_value" => "https://foo.bar"}]
               }
             }

      assert [{:reindex, :structures, indexed_structures}] = IndexWorkerMock.calls()
      assert Enum.count(indexed_structures) == 1
      assert jobs = all_enqueued(worker: EmbeddingsUpsertBatch)
      assert Enum.count(jobs) == 1
    end

    test "removes empty fields when note is deprecated", %{
      claims: %{user_id: user_id} = claims,
      domain: %{id: domain_id}
    } do
      CacheHelpers.put_session_permissions(claims, %{
        create_structure_note: [domain_id],
        publish_structure_note_from_draft: [domain_id],
        edit_structure_note: [domain_id],
        view_data_structure: [domain_id]
      })

      data_structure =
        insert(:data_structure, external_id: "ex_id23", domain_ids: [domain_id])

      valid_structure_note("type_1", data_structure,
        df_content: %{
          "text" => %{"value" => "foo", "origin" => "user"},
          "critical" => %{"value" => "No", "origin" => "user"},
          "urls_one_or_none" => %{
            "value" => [%{"url_name" => "", "url_value" => "https://foo.bar"}],
            "origin" => "user"
          }
        },
        status: "deprecated"
      )

      {:ok, %{update_notes: update_notes}} =
        Upload.structures(
          %{
            path: "test/fixtures/xlsx/upload_empty_with_status.xlsx",
            file_name: "upload_empty_with_status.xlsx",
            hash: "hash"
          },
          user_id: user_id,
          claims: claims,
          task_reference: "oban:1"
        )

      {_id, note} =
        Enum.find(update_notes, fn
          {_id, %{data_structure: data_structure}} ->
            data_structure.external_id == "ex_id23"
        end)

      assert note.status == :draft

      assert note.df_content == %{
               "critical" => %{"origin" => "file", "value" => "Yes"},
               "enriched_text" => %{"origin" => "file", "value" => %{}},
               "text" => %{"origin" => "file", "value" => ""},
               "urls_one_or_none" => %{
                 "origin" => "user",
                 "value" => [%{"url_name" => "", "url_value" => "https://foo.bar"}]
               }
             }

      assert [{:reindex, :structures, indexed_structures}] = IndexWorkerMock.calls()
      assert Enum.count(indexed_structures) == 1
      assert jobs = all_enqueued(worker: EmbeddingsUpsertBatch)
      assert Enum.count(jobs) == 1
    end

    test "removes empty fields when note is deprecated and auto published = true", %{
      claims: %{user_id: user_id} = claims,
      domain: %{id: domain_id}
    } do
      CacheHelpers.put_session_permissions(claims, %{
        create_structure_note: [domain_id],
        publish_structure_note_from_draft: [domain_id],
        edit_structure_note: [domain_id],
        view_data_structure: [domain_id]
      })

      data_structure =
        insert(:data_structure, external_id: "ex_id23", domain_ids: [domain_id])

      valid_structure_note("type_1", data_structure,
        df_content: %{
          "text" => %{"value" => "foo", "origin" => "user"},
          "critical" => %{"value" => "No", "origin" => "user"},
          "urls_one_or_none" => %{
            "value" => [%{"url_name" => "", "url_value" => "https://foo.bar"}],
            "origin" => "user"
          }
        },
        status: "deprecated"
      )

      {:ok, %{update_notes: update_notes}} =
        Upload.structures(
          %{
            path: "test/fixtures/xlsx/upload_empty_with_status.xlsx",
            file_name: "upload_empty_with_status.xlsx",
            hash: "hash"
          },
          user_id: user_id,
          claims: claims,
          task_reference: "oban:1",
          auto_publish: true
        )

      {_id, note} =
        Enum.find(update_notes, fn
          {_id, %{data_structure: data_structure}} ->
            data_structure.external_id == "ex_id23"
        end)

      assert note.status == :published

      assert note.df_content == %{
               "critical" => %{"origin" => "file", "value" => "Yes"},
               "enriched_text" => %{"origin" => "file", "value" => %{}},
               "text" => %{"origin" => "file", "value" => ""},
               "urls_one_or_none" => %{
                 "origin" => "user",
                 "value" => [%{"url_name" => "", "url_value" => "https://foo.bar"}]
               }
             }

      assert [{:reindex, :structures, indexed_structures}] = IndexWorkerMock.calls()
      assert Enum.count(indexed_structures) == 1
      assert jobs = all_enqueued(worker: EmbeddingsUpsertBatch)
      assert Enum.count(jobs) == 1
    end

    test "uploads table field and removes tail field when it's empty", %{
      claims: %{user_id: user_id} = claims,
      domain: %{id: domain_id}
    } do
      CacheHelpers.put_session_permissions(claims, %{
        create_structure_note: [domain_id],
        publish_structure_note_from_draft: [domain_id],
        edit_structure_note: [domain_id],
        view_data_structure: [domain_id]
      })

      %{id: id, name: type} =
        CacheHelpers.insert_template(content: @content_for_type_4, type: "type_4", name: "type_4")

      insert(:data_structure_type, name: type, template_id: id)

      data_structure =
        insert(:data_structure, external_id: "ex_id23", domain_ids: [domain_id])

      valid_structure_note("type_4", data_structure,
        df_content: %{"string_field" => %{"origin" => "user", "value" => "foo"}}
      )

      {:ok, %{update_notes: update_notes}} =
        Upload.structures(
          %{
            path: "test/fixtures/xlsx/upload_table.xlsx",
            file_name: "upload_table.xlsx",
            hash: "hash"
          },
          user_id: user_id,
          claims: claims,
          task_reference: "oban:1",
          auto_publish: true
        )

      {_id, note} =
        Enum.find(update_notes, fn
          {_id, %{data_structure: data_structure}} ->
            data_structure.external_id == "ex_id23"
        end)

      assert note.df_content == %{
               "string_field" => %{"origin" => "file", "value" => ""},
               "table_field" => %{
                 "origin" => "file",
                 "value" => [
                   %{"First Column" => "First Field", "Second Column" => "Second Field"},
                   %{"First Column" => "Third Field", "Second Column" => "Fourth Field"}
                 ]
               }
             }

      assert [{:reindex, :structures, indexed_structures}] = IndexWorkerMock.calls()
      assert Enum.count(indexed_structures) == 1
      assert jobs = all_enqueued(worker: EmbeddingsUpsertBatch)
      assert Enum.count(jobs) == 1
    end

    test "removes table field", %{
      claims: %{user_id: user_id} = claims,
      domain: %{id: domain_id}
    } do
      CacheHelpers.put_session_permissions(claims, %{
        create_structure_note: [domain_id],
        publish_structure_note_from_draft: [domain_id],
        edit_structure_note: [domain_id],
        view_data_structure: [domain_id]
      })

      %{id: id, name: type} =
        CacheHelpers.insert_template(content: @content_for_type_4, type: "type_4", name: "type_4")

      insert(:data_structure_type, name: type, template_id: id)

      data_structure =
        insert(:data_structure, external_id: "ex_id23", domain_ids: [domain_id])

      valid_structure_note("type_4", data_structure,
        df_content: %{
          "string_field" => %{"origin" => "file", "value" => "foo"},
          "table_field" => %{
            "origin" => "file",
            "value" => [
              %{"First Column" => "First Field", "Second Column" => "Second Field"},
              %{"First Column" => "Third Field", "Second Column" => "Fourth Field"}
            ]
          }
        },
        status: "published"
      )

      {:ok, %{update_notes: update_notes}} =
        Upload.structures(
          %{
            path: "test/fixtures/xlsx/upload_table_empty.xlsx",
            file_name: "upload_table_empty.xlsx",
            hash: "hash"
          },
          user_id: user_id,
          claims: claims,
          task_reference: "oban:1",
          auto_publish: true
        )

      {_id, note} =
        Enum.find(update_notes, fn
          {_id, %{data_structure: data_structure}} ->
            data_structure.external_id == "ex_id23"
        end)

      assert note.df_content == %{
               "string_field" => %{"origin" => "file", "value" => ""},
               "table_field" => %{
                 "origin" => "file",
                 "value" => []
               }
             }

      assert [{:reindex, :structures, indexed_structures}] = IndexWorkerMock.calls()
      assert Enum.count(indexed_structures) == 1
      assert jobs = all_enqueued(worker: EmbeddingsUpsertBatch)
      assert Enum.count(jobs) == 1
    end

    test "uploads dependent fields", %{
      claims: %{user_id: user_id} = claims,
      domain: %{id: domain_id}
    } do
      CacheHelpers.put_session_permissions(claims, %{
        create_structure_note: [domain_id],
        publish_structure_note_from_draft: [domain_id],
        edit_structure_note: [domain_id],
        view_data_structure: [domain_id]
      })

      %{id: id, name: type} =
        CacheHelpers.insert_template(content: @content_for_type_5, type: "type_5", name: "type_5")

      insert(:data_structure_type, name: type, template_id: id)

      data_structure =
        insert(:data_structure, external_id: "ex_id23", domain_ids: [domain_id])

      valid_structure_note("type_5", data_structure,
        df_content: %{"Level 1" => %{"origin" => "file", "value" => "A"}}
      )

      {:ok, %{update_notes: update_notes}} =
        Upload.structures(
          %{
            path: "test/fixtures/xlsx/upload_dependent.xlsx",
            file_name: "upload_dependent.xlsx",
            hash: "hash"
          },
          user_id: user_id,
          claims: claims,
          task_reference: "oban:1"
        )

      {_id, note} =
        Enum.find(update_notes, fn
          {_id, %{data_structure: data_structure}} ->
            data_structure.external_id == "ex_id23"
        end)

      assert note.df_content == %{
               "Level 1" => %{"origin" => "file", "value" => "A"},
               "Level 2" => %{"origin" => "file", "value" => "A2"}
             }

      assert [{:reindex, :structures, indexed_structures}] = IndexWorkerMock.calls()
      assert Enum.count(indexed_structures) == 1
      assert jobs = all_enqueued(worker: EmbeddingsUpsertBatch)
      assert Enum.count(jobs) == 1
    end

    setup do
      CacheHelpers.put_i18n_messages("es", [
        %{message_id: "fields.label_i18n_test.Dropdown Fixed", definition: "Dropdown Fijo"},
        %{message_id: "fields.label_i18n_test.Dropdown Fixed.pear", definition: "pera"},
        %{message_id: "fields.label_i18n_test.Dropdown Fixed.banana", definition: "plátano"},
        %{message_id: "fields.label_i18n_test.Dropdown Fixed.apple", definition: "manzana"},
        %{message_id: "fields.label_i18n_test.Radio Fixed", definition: "Radio Fijo"},
        %{message_id: "fields.label_i18n_test.Radio Fixed.pear", definition: "pera"},
        %{message_id: "fields.label_i18n_test.Radio Fixed.banana", definition: "plátano"},
        %{message_id: "fields.label_i18n_test.Radio Fixed.apple", definition: "manzana"},
        %{message_id: "fields.label_i18n_test.Checkbox Fixed", definition: "Checkbox Fijo"},
        %{message_id: "fields.label_i18n_test.Checkbox Fixed.pear", definition: "pera"},
        %{message_id: "fields.label_i18n_test.Checkbox Fixed.banana", definition: "plátano"},
        %{message_id: "fields.label_i18n_test.Checkbox Fixed.apple", definition: "manzana"}
      ])

      :ok
    end

    test "upload file with lang" do
      %{user_id: user_id} = claims = build(:claims, role: "admin")

      attrs = %{
        path: "test/fixtures/xlsx/upload_native_lang.xlsx",
        file_name: "upload_native_lang.xlsx",
        hash: "hash"
      }

      {:ok, %{update_notes: update_notes}} =
        Upload.structures(
          attrs,
          user_id: user_id,
          claims: claims,
          task_reference: "oban:1",
          lang: "es"
        )

      updated_notes = Map.values(update_notes)

      assert note =
               Enum.find(updated_notes, fn %{data_structure: structure} ->
                 structure.external_id == "ex_id21"
               end)

      assert note.df_content == %{
               "i18n_test.checkbox.fixed" => %{
                 "origin" => "file",
                 "value" => ["pear", "apple"]
               },
               "i18n_test.dropdown.fixed" => %{"origin" => "file", "value" => "peach"},
               "i18n_test.radio.fixed" => %{"origin" => "file", "value" => "apple"},
               "i18n_test_no_translate" => %{
                 "origin" => "file",
                 "value" => "SIN TRADUCCION"
               }
             }

      assert note =
               Enum.find(updated_notes, fn %{data_structure: structure} ->
                 structure.external_id == "ex_id22"
               end)

      assert note.df_content == %{
               "i18n_test.checkbox.fixed" => %{"value" => ["pear", "banana"], "origin" => "file"},
               "i18n_test.dropdown.fixed" => %{"value" => "apple", "origin" => "file"},
               "i18n_test.radio.fixed" => %{"value" => "banana", "origin" => "file"},
               "i18n_test_no_translate" => %{"value" => "SIN TRADUCCION", "origin" => "file"}
             }
    end

    test "returns error under invalid i18n values" do
      %{user_id: user_id} = claims = build(:claims, role: "admin")

      attrs = %{
        path: "test/fixtures/xlsx/upload_native_lang_error.xlsx",
        file_name: "upload_native_lang.xlsx",
        hash: "hash"
      }

      {:ok, %{update_notes: update_notes}} =
        Upload.structures(
          attrs,
          user_id: user_id,
          claims: claims,
          task_reference: "oban:1",
          lang: "es"
        )

      assert {_id, {:error, {changeset, _data_structure}}} =
               Enum.find(update_notes, fn
                 {_id, {:error, {_changeset, data_structure}}} ->
                   data_structure.external_id == "ex_id21"
               end)

      assert {_message, detail} = changeset.errors[:df_content]

      assert {"has an invalid entry", type} =
               Enum.find_value(detail, fn
                 {:"i18n_test.checkbox.fixed", v} -> v
                 {_other, _v} -> false
               end)

      assert type[:validation] == :subset

      assert {"is invalid", type} =
               Enum.find_value(detail, fn
                 {:"i18n_test.radio.fixed", v} -> v
                 {_other, _v} -> false
               end)

      assert type[:validation] == :inclusion
    end
  end

  describe "TdDd.XLSX.Upload.structures_async/3" do
    test "inserts oban job for async processing" do
      upload_dir = "test/strutures_async"
      on_exit(fn -> File.rm_rf!(upload_dir) end)

      path = "test/fixtures/xlsx/upload.xlsx"
      file_name = "upload.xlsx"
      target_path = Path.join([upload_dir, file_name])
      hash = Base.encode16("foo")
      claims = build(:claims, role: "user")

      opts = %{
        "auto_publish" => true,
        "lang" => "en",
        "user_id" => claims.user_id,
        "claims" => claims,
        "upload_dir" => upload_dir
      }

      assert {:ok, %Oban.Job{}} =
               Upload.structures_async(%{path: path, filename: file_name}, hash, opts)

      claims = %{
        "user_id" => claims.user_id,
        "user_name" => claims.user_name,
        "jti" => claims.jti
      }

      opts = Map.put(opts, "claims", claims)

      assert_enqueued worker: UploadWorker,
                      args: %{
                        path: target_path,
                        hash: hash,
                        file_name: file_name,
                        opts: opts
                      },
                      queue: :xlsx_upload_queue

      assert File.exists?(target_path)
    end
  end

  defp valid_structure_note(type, data_structure, opts) do
    insert(:data_structure_version,
      type: type,
      data_structure: data_structure
    )

    insert(:structure_note, [data_structure: data_structure] ++ opts)
  end
end
