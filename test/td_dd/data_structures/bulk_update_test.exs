defmodule TdDd.DataStructures.BulkUpdateTest do
  use TdDd.DataCase

  import Mox
  import TdDd.TestOperators

  alias TdCore.Search.IndexWorkerMock
  alias TdDd.DataStructures
  alias TdDd.DataStructures.BulkUpdate
  alias TdDd.DataStructures.DataStructureVersions.Workers.EmbeddingsUpsertBatch
  alias TdDd.DataStructures.StructureNotes

  require Logger

  @moduletag sandbox: :shared
  @valid_content %{
    "string" => %{"value" => "present", "origin" => "user"},
    "list" => %{"value" => "one", "origin" => "user"}
  }
  @valid_params %{"df_content" => @valid_content}
  @c1 [
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
          "cardinality" => "+",
          "description" => "description",
          "label" => "Role",
          "name" => "role",
          "type" => "user",
          "values" => %{"role_users" => "Data Owner"}
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
          "label" => "Numeric",
          "name" => "integer",
          "type" => "integer",
          "values" => nil,
          "widget" => "number"
        }
      ]
    }
  ]

  @c2 [
    %{
      "name" => "group",
      "fields" => [
        %{
          "cardinality" => "?",
          "label" => "Texto Enriquecido",
          "name" => "enriched_text",
          "type" => "enriched_text",
          "widget" => "enriched_text"
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
          "name" => "hierarchy_name_1",
          "label" => "Hierarchy name 1",
          "type" => "hierarchy",
          "values" => %{"hierarchy" => %{"id" => 1}},
          "widget" => "dropdown"
        },
        %{
          "cardinality" => "*",
          "name" => "hierarchy_name_2",
          "type" => "hierarchy",
          "label" => "Hierarchy name 2",
          "values" => %{"hierarchy" => %{"id" => 1}},
          "widget" => "dropdown"
        },
        %{
          "name" => "father",
          "type" => "string",
          "label" => "father",
          "values" => %{"fixed" => ["a1", "a2", "b1", "b2"]},
          "widget" => "dropdown",
          "default" => %{"value" => "", "origin" => "default"},
          "cardinality" => "?",
          "subscribable" => false,
          "ai_suggestion" => false
        },
        %{
          "name" => "son",
          "type" => "string",
          "label" => "son",
          "values" => %{
            "switch" => %{
              "on" => "father",
              "values" => %{
                "a1" => ["a11", "a12", "a13"],
                "a2" => ["a21", "a22", "a23"],
                "b1" => ["b11", "b12", "b13"],
                "b2" => ["b21", "b22", "b23"]
              }
            }
          },
          "widget" => "dropdown",
          "default" => %{"value" => "", "origin" => "default"},
          "cardinality" => "?",
          "subscribable" => false,
          "ai_suggestion" => false
        }
      ]
    }
  ]

  @c3 [
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

  @url_template [
    %{
      "name" => "url_template",
      "fields" => [
        %{
          "cardinality" => "?",
          "label" => "Text",
          "name" => "text",
          "type" => "string",
          "widget" => "string"
        },
        %{
          "cardinality" => "*",
          "label" => "Urls None or More",
          "name" => "urls_none_or_more",
          "type" => "url",
          "values" => nil,
          "widget" => "pair_list"
        }
      ]
    }
  ]
  @default_lang "en"

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    start_supervised!(TdDd.Search.StructureEnricher)

    stub(MockClusterHandler, :call, fn :ai, TdAi.Indices, :exists_enabled?, [] ->
      {:ok, true}
    end)

    %{id: template_id, name: template_name} = template = CacheHelpers.insert_template()
    CacheHelpers.insert_structure_type(name: template_name, template_id: template_id)
    hierarchy = create_hierarchy()
    CacheHelpers.insert_hierarchy(hierarchy)

    IndexWorkerMock.clear()

    [template: template, type: template_name, hierarchy: hierarchy]
  end

  describe "parse_file/1" do
    test "ignores empty lines" do
      assert {:ok, rows} = BulkUpdate.parse_file("test/fixtures/td3071/empty_lines.csv")

      assert rows == [
               %{"bar" => "2", "foo" => "1"},
               %{"bar" => "4", "foo" => "3"}
             ]
    end

    test "converts Windows 1252 to UTF-8" do
      assert {:ok, rows} = BulkUpdate.parse_file("test/fixtures/td3071/cp1252.csv")

      assert rows == [
               %{"encoding" => "CP1252", "text" => "“IS WONDERFUL”"},
               %{"encoding" => "UTF-8", "text" => "R.I.P."}
             ]
    end
  end

  describe "update_all/4" do
    test "update all data structures with valid data", %{type: type} do
      IndexWorkerMock.clear()
      %{user_id: user_id} = claims = build(:claims)

      ids =
        1..10
        |> Enum.map(fn _ ->
          valid_structure_note(type,
            df_content: %{"string" => %{"value" => "foo", "origin" => "user"}}
          )
        end)
        |> Enum.map(& &1.data_structure_id)

      assert {:ok, %{update_notes: update_notes}} =
               BulkUpdate.update_all(ids, @valid_params, claims, false)

      assert Map.keys(update_notes) ||| ids

      latest_structure_notes = Enum.map(ids, &StructureNotes.get_latest_structure_note/1)

      assert latest_structure_notes
             |> Enum.map(& &1.df_content)
             |> Enum.all?(&(&1 == @valid_content))

      assert latest_structure_notes
             |> Enum.map(& &1.last_changed_by)
             |> Enum.all?(&(&1 == user_id))

      assert [{:reindex, :structures, ids_reindex}] = IndexWorkerMock.calls()
      assert length(ids_reindex) == length(ids)
      assert [job] = all_enqueued(worker: EmbeddingsUpsertBatch)
      assert MapSet.equal?(MapSet.new(ids_reindex), MapSet.new(job.args["data_structure_ids"]))
    end

    test "update all data structures with valid data with duplicate ids", %{type: type} do
      IndexWorkerMock.clear()
      claims = build(:claims)

      ids_uniques =
        1..10
        |> Enum.map(fn _ ->
          valid_structure_note(type,
            df_content: %{"string" => %{"value" => "foo", "origin" => "user"}}
          )
        end)
        |> Enum.map(& &1.data_structure_id)

      duplicate_id = List.first(ids_uniques)
      ids = [duplicate_id, duplicate_id | ids_uniques]

      assert {:ok, %{update_notes: update_notes}} =
               BulkUpdate.update_all(ids, @valid_params, claims, false)

      assert Map.keys(update_notes) ||| Enum.uniq(ids)

      assert [{:reindex, :structures, ids_reindex}] = IndexWorkerMock.calls()
      assert length(ids_reindex) == length(ids_uniques)
    end

    test "update all data structures by other user with valid data", %{type: type} do
      IndexWorkerMock.clear()
      %{user_id: user_id} = claims = build(:claims)

      ids =
        1..10
        |> Enum.map(fn _ ->
          valid_structure_note(type,
            df_content: %{"string" => %{"value" => "foo", "origin" => "user"}},
            last_changed_by: user_id + 1
          )
        end)
        |> Enum.map(& &1.data_structure_id)

      assert {:ok, %{update_notes: _update_notes}} =
               BulkUpdate.update_all(ids, @valid_params, claims, false)

      assert ids
             |> Enum.map(&StructureNotes.get_latest_structure_note/1)
             |> Enum.map(& &1.last_changed_by)
             |> Enum.all?(&(&1 == user_id))
    end

    test "update and publish all data structures with valid data", %{type: type} do
      IndexWorkerMock.clear()
      claims = build(:claims)

      ids =
        1..10
        |> Enum.map(fn _ ->
          valid_structure_note(type,
            df_content: %{"string" => %{"value" => "foo", "origin" => "user"}}
          )
        end)
        |> Enum.map(& &1.data_structure_id)

      assert {:ok, %{update_notes: update_notes}} =
               BulkUpdate.update_all(ids, @valid_params, claims, true)

      assert Map.keys(update_notes) ||| ids

      latest_structure_notes = Enum.map(ids, &StructureNotes.get_latest_structure_note/1)

      assert latest_structure_notes
             |> Enum.map(& &1.df_content)
             |> Enum.all?(&(&1 == @valid_content))

      assert latest_structure_notes
             |> Enum.map(& &1.status)
             |> Enum.all?(&(&1 == :published))

      assert [{:reindex, :structures, ^ids}] = IndexWorkerMock.calls()
      assert [job] = all_enqueued(worker: EmbeddingsUpsertBatch)
      assert MapSet.equal?(MapSet.new(ids), MapSet.new(job.args["data_structure_ids"]))
    end

    test "update and republish only data structures with different valid data", %{type: type} do
      IndexWorkerMock.clear()
      claims = build(:claims)

      ids =
        (1..3
         |> Enum.map(fn _ ->
           valid_structure_note(type,
             df_content: %{"string" => %{"value" => "foo", "origin" => "user"}}
           )
         end)
         |> Enum.map(& &1.data_structure_id)) ++
          (1..4
           |> Enum.map(fn _ ->
             valid_structure_note(type,
               df_content: %{"string" => %{"value" => "foo", "origin" => "user"}},
               status: :published
             )
           end)
           |> Enum.map(& &1.data_structure_id)) ++
          (1..3
           |> Enum.map(fn _ ->
             valid_structure_note(type,
               df_content: %{"string" => %{"value" => "foo", "origin" => "user"}}
             )
           end)
           |> Enum.map(& &1.data_structure_id))

      assert [1, 1, 1, 1, 1, 1, 1, 1, 1, 1] ==
               Enum.map(ids, fn id ->
                 Map.get(StructureNotes.get_latest_structure_note(id), :version)
               end)

      BulkUpdate.update_all(ids, @valid_params, claims, true)

      assert [1, 1, 1, 2, 2, 2, 2, 1, 1, 1] ==
               Enum.map(ids, fn id ->
                 Map.get(StructureNotes.get_latest_structure_note(id), :version)
               end)

      BulkUpdate.update_all(ids, @valid_params, claims, true)

      assert [1, 1, 1, 2, 2, 2, 2, 1, 1, 1] ==
               Enum.map(ids, fn id ->
                 Map.get(StructureNotes.get_latest_structure_note(id), :version)
               end)

      assert [{:reindex, :structures, ids_reindex_1}, {:reindex, :structures, ids_reindex_2}] =
               IndexWorkerMock.calls()

      assert length(ids_reindex_1) == length(ids)
      assert length(ids_reindex_2) == length(ids)
      jobs = all_enqueued(worker: EmbeddingsUpsertBatch) |> Enum.sort_by(& &1.id)
      assert Enum.count(jobs) == 2

      assert MapSet.equal?(
               MapSet.new(ids_reindex_1),
               MapSet.new(Enum.at(jobs, 0).args["data_structure_ids"])
             )

      assert MapSet.equal?(
               MapSet.new(ids_reindex_2),
               MapSet.new(Enum.at(jobs, 1).args["data_structure_ids"])
             )
    end

    test "ignores unchanged data structures", %{type: type} do
      IndexWorkerMock.clear()
      %{user_id: user_id} = claims = build(:claims)
      fixed_datetime = ~N[2020-01-01 00:00:00]
      timestamps = [inserted_at: fixed_datetime, updated_at: fixed_datetime]
      changed_by = [last_changed_by: user_id]

      changed_ids =
        1..5
        |> Enum.map(fn _ ->
          valid_structure_note(
            type,
            [
              df_content: %{
                "string" => %{"value" => "foo", "origin" => "user"},
                "list" => %{"value" => "bar", "origin" => "user"}
              }
            ] ++ timestamps ++ changed_by
          )
        end)
        |> Enum.map(& &1.data_structure_id)

      unchanged_ids =
        1..5
        |> Enum.map(fn _ ->
          valid_structure_note(type, [df_content: @valid_content] ++ timestamps ++ changed_by)
        end)
        |> Enum.map(& &1.data_structure_id)

      ids = unchanged_ids ++ changed_ids
      assert {:ok, _} = BulkUpdate.update_all(ids, @valid_params, claims, false)

      notes =
        ids |> Enum.map(&StructureNotes.list_structure_notes/1) |> Enum.map(&Enum.at(&1, -1))

      changed_notes_ds_ids =
        notes
        |> Enum.reject(&(&1.updated_at == &1.inserted_at))
        |> Enum.map(& &1.data_structure_id)

      assert notes
             |> Enum.map(& &1.df_content)
             |> Enum.all?(&(&1 == @valid_content))

      assert Enum.count(changed_notes_ds_ids) == 5
      assert changed_notes_ds_ids ||| changed_ids
      assert [{:reindex, :structures, ids_reindex}] = IndexWorkerMock.calls()
      assert length(ids_reindex) == length(ids)
      assert [job] = all_enqueued(worker: EmbeddingsUpsertBatch)
      assert MapSet.equal?(MapSet.new(ids), MapSet.new(job.args["data_structure_ids"]))
    end

    test "returns an error if a structure has no template", %{type: type} do
      IndexWorkerMock.clear()
      claims = build(:claims)

      content = %{
        "string" => %{"value" => "foo", "origin" => "user"},
        "list" => %{"value" => "bar", "origin" => "user"}
      }

      ids =
        1..10
        |> Enum.map(fn
          9 -> invalid_structure()
          _ -> valid_structure_note(type, df_content: content)
        end)
        |> Enum.map(& &1.data_structure_id)

      {:ok, %{update_notes: update_notes}} =
        BulkUpdate.update_all(ids, @valid_params, claims, false)

      [_, errored_notes] = BulkUpdate.split_succeeded_errors(update_notes)

      [first_errored_note] = Enum.map(errored_notes, fn {_k, v} -> v end)
      assert {:error, {%{errors: errors}, data_structure}} = first_errored_note
      assert %{external_id: "the bad one"} = data_structure
      assert {"missing_type", _} = errors[:df_content]
      assert [{:reindex, :structures, ids_reindex}] = IndexWorkerMock.calls()
      assert length(ids_reindex) == 10
      assert [job] = all_enqueued(worker: EmbeddingsUpsertBatch)
      assert MapSet.equal?(MapSet.new(ids), MapSet.new(job.args["data_structure_ids"]))
    end

    test "only updates specified fields", %{type: type} do
      IndexWorkerMock.clear()
      claims = build(:claims)

      initial_content =
        Map.replace!(@valid_content, "string", %{"value" => "initial", "origin" => "user"})

      structure_count = 10

      ids =
        1..structure_count
        |> Enum.map(fn _ -> valid_structure_note(type, df_content: initial_content) end)
        |> Enum.map(& &1.data_structure_id)

      assert {:ok, %{update_notes: update_notes}} =
               BulkUpdate.update_all(
                 ids,
                 %{"df_content" => %{"string" => %{"value" => "updated", "origin" => "user"}}},
                 claims,
                 false
               )

      assert Map.keys(update_notes) ||| ids

      df_contents =
        ids
        |> Enum.map(&StructureNotes.list_structure_notes/1)
        |> Enum.filter(&(Enum.count(&1) == 1))
        |> Enum.map(&Enum.at(&1, -1).df_content)

      assert Enum.count(df_contents) == structure_count

      Enum.each(df_contents, fn df_content ->
        assert df_content == %{
                 "string" => %{"value" => "updated", "origin" => "user"},
                 "list" => initial_content["list"]
               }
      end)

      assert [{:reindex, :structures, ids_reindex}] = IndexWorkerMock.calls()
      assert length(ids_reindex) == structure_count
      assert [job] = all_enqueued(worker: EmbeddingsUpsertBatch)
      assert MapSet.equal?(MapSet.new(ids), MapSet.new(job.args["data_structure_ids"]))
    end

    test "only updates specified fields for published notes", %{type: type} do
      IndexWorkerMock.clear()
      claims = build(:claims)
      structure_count = 10

      ids =
        1..structure_count
        |> Enum.map(fn _ -> insert(:data_structure_version, type: type) end)
        |> Enum.map(& &1.data_structure_id)

      assert {:ok, %{update_notes: update_notes}} =
               BulkUpdate.update_all(
                 ids,
                 %{"df_content" => %{"string" => %{"value" => "updated", "origin" => "user"}}},
                 claims,
                 false
               )

      assert Map.keys(update_notes) ||| ids

      df_contents =
        Enum.map(ids, fn id ->
          id
          |> StructureNotes.get_latest_structure_note()
          |> Map.get(:df_content)
        end)

      assert Enum.count(df_contents) == structure_count

      Enum.each(df_contents, fn df_content ->
        assert df_content == %{"string" => %{"value" => "updated", "origin" => "user"}}
      end)

      assert [{:reindex, :structures, ids_reindex}] = IndexWorkerMock.calls()
      assert length(ids_reindex) == structure_count
      assert [job] = all_enqueued(worker: EmbeddingsUpsertBatch)
      assert MapSet.equal?(MapSet.new(ids), MapSet.new(job.args["data_structure_ids"]))
    end

    test "when bulk updating will allow to create templates with missing required fields", %{
      type: type
    } do
      IndexWorkerMock.clear()
      claims = build(:claims)

      initial_content =
        Map.replace!(@valid_content, "string", %{"value" => "initial", "origin" => "user"})

      structure_count = 10

      ids =
        1..structure_count
        |> Enum.map(fn _ ->
          valid_structure_note(type,
            df_content: initial_content,
            status: :published
          )
        end)
        |> Enum.map(& &1.data_structure_id)

      assert {:ok, %{update_notes: update_notes}} =
               BulkUpdate.update_all(
                 ids,
                 %{"df_content" => %{"string" => %{"value" => "updated", "origin" => "user"}}},
                 claims,
                 false
               )

      assert Map.keys(update_notes) ||| ids

      df_contents =
        Enum.map(ids, fn id ->
          id
          |> StructureNotes.get_latest_structure_note()
          |> Map.get(:df_content)
        end)

      assert Enum.count(df_contents) == structure_count

      Enum.each(df_contents, fn df_content ->
        assert df_content == %{
                 "string" => %{"value" => "updated", "origin" => "user"},
                 "list" => initial_content["list"]
               }
      end)

      assert [{:reindex, :structures, ids_reindex}] = IndexWorkerMock.calls()
      assert length(ids_reindex) == structure_count
      assert [job] = all_enqueued(worker: EmbeddingsUpsertBatch)
      assert MapSet.equal?(MapSet.new(ids), MapSet.new(job.args["data_structure_ids"]))
    end

    test "only validates specified fields", %{type: type} do
      claims = build(:claims)

      id =
        valid_structure_note(type,
          df_content: %{"list" => %{"value" => "two", "origin" => "user"}}
        ).data_structure_id

      assert {:ok, %{update_notes: _update_notes}} =
               BulkUpdate.update_all(
                 [id],
                 %{"df_content" => %{"list" => %{"value" => "one", "origin" => "user"}}},
                 claims,
                 false
               )

      %{df_content: df_content} = StructureNotes.get_latest_structure_note(id)

      assert df_content == %{"list" => %{"value" => "one", "origin" => "user"}}
    end

    test "ignores empty fields", %{type: type} do
      IndexWorkerMock.clear()
      claims = build(:claims)

      initial_content =
        Map.replace!(@valid_content, "string", %{"value" => "initial", "origin" => "user"})

      structure_count = 10

      ids =
        1..structure_count
        |> Enum.map(fn _ -> valid_structure_note(type, df_content: initial_content) end)
        |> Enum.map(& &1.data_structure_id)

      assert {:ok, %{update_notes: update_notes}} =
               BulkUpdate.update_all(
                 ids,
                 %{
                   "df_content" => %{
                     "string" => %{"value" => "", "origin" => "user"},
                     "list" => %{"value" => "two", "origin" => "user"}
                   }
                 },
                 claims,
                 false
               )

      assert Map.keys(update_notes) ||| ids

      df_contents =
        ids
        |> Enum.map(&StructureNotes.list_structure_notes/1)
        |> Enum.filter(&(Enum.count(&1) == 1))
        |> Enum.map(&Enum.at(&1, -1).df_content)

      assert Enum.count(df_contents) == structure_count

      Enum.each(df_contents, fn df_content ->
        assert df_content == %{
                 "string" => initial_content["string"],
                 "list" => %{"value" => "two", "origin" => "user"}
               }
      end)

      assert [{:reindex, :structures, ids_reindex}] = IndexWorkerMock.calls()
      assert length(ids_reindex) == structure_count
      assert [job] = all_enqueued(worker: EmbeddingsUpsertBatch)
      assert MapSet.equal?(MapSet.new(ids), MapSet.new(job.args["data_structure_ids"]))
    end
  end

  describe "from_csv/2" do
    setup [:from_csv_templates, :insert_i18n_messages]

    defp get_df_content_from_ext_id(ext_id) do
      ext_id
      |> DataStructures.get_data_structure_by_external_id()
      |> Map.get(:id)
      |> StructureNotes.get_latest_structure_note()
      |> Map.get(:df_content)
    end

    test "update all data structures content", %{sts: sts, hierarchy: %{nodes: nodes}} do
      IndexWorkerMock.clear()
      [%{key: key_node_1}, %{key: key_node_2} | _] = nodes

      %{user_id: user_id} = build(:claims)
      structure_ids = Enum.map(sts, & &1.data_structure_id)

      ["ex_id1", "ex_id6"]
      |> Enum.each(fn ex_id ->
        ex_id
        |> DataStructures.get_data_structure_by_external_id()
        |> Map.get(:id)
        |> StructureNotes.get_latest_structure_note()
        |> StructureNotes.delete_structure_note(user_id, is_bulk_update: true)
      end)

      %{domain_ids: [domain_id]} = DataStructures.get_data_structure_by_external_id("ex_id1")

      user_ids =
        Enum.map(["Role", "Role 1", "Role 2"], fn full_name ->
          CacheHelpers.insert_user(full_name: full_name).id
        end)

      CacheHelpers.insert_acl(domain_id, "Data Owner", user_ids)
      upload = %{path: "test/fixtures/td2942/upload.csv"}

      assert {contents, [] = errors} =
               BulkUpdate.from_csv(upload, @default_lang)

      assert {:ok, %{update_notes: update_notes}} =
               BulkUpdate.file_bulk_update(contents, errors, user_id)

      ids = Map.keys(update_notes)
      assert length(ids) == 14
      assert Enum.all?(ids, fn id -> id in structure_ids end)

      assert %{
               "text" => %{"value" => "text", "origin" => "file"},
               "critical" => %{"value" => "Yes", "origin" => "file"},
               "role" => %{"value" => ["Role", "Role 1"], "origin" => "file"},
               "key_value" => %{"value" => [""], "origin" => "file"}
             } = get_df_content_from_ext_id("ex_id1")

      assert %{
               "text" => %{"value" => "text2", "origin" => "file"},
               "critical" => %{"value" => "Yes", "origin" => "file"},
               "role" => %{"value" => ["Role"], "origin" => "file"}
             } = get_df_content_from_ext_id("ex_id2")

      assert %{
               "text" => %{"value" => "foo", "origin" => "user"},
               "critical" => %{"value" => "No", "origin" => "file"},
               "role" => %{"value" => ["Role"], "origin" => "file"}
             } = get_df_content_from_ext_id("ex_id3")

      assert %{
               "text" => %{"value" => "foo", "origin" => "user"},
               "critical" => %{"value" => "No", "origin" => "file"},
               "role" => %{"value" => ["Role 1"], "origin" => "file"}
             } = get_df_content_from_ext_id("ex_id4")

      assert %{
               "text" => %{"value" => "foo", "origin" => "user"},
               "critical" => %{"value" => "No", "origin" => "file"},
               "role" => %{"value" => ["Role 2"], "origin" => "file"},
               "key_value" => %{"value" => ["2"], "origin" => "file"}
             } = get_df_content_from_ext_id("ex_id5")

      text = to_enriched_text("I’m 6")

      assert %{"enriched_text" => %{"value" => ^text, "origin" => "file"}} =
               get_df_content_from_ext_id("ex_id6")

      text = to_enriched_text("Enriched text")

      assert %{
               "enriched_text" => %{"value" => ^text, "origin" => "file"},
               "integer" => %{"value" => 3, "origin" => "file"}
             } = get_df_content_from_ext_id("ex_id7")

      assert %{
               "integer" => %{"value" => 2, "origin" => "file"}
             } = get_df_content_from_ext_id("ex_id8")

      text = to_enriched_text("I’m 9")

      assert %{
               "enriched_text" => %{"value" => ^text, "origin" => "file"},
               "integer" => %{"value" => 9, "origin" => "file"}
             } = get_df_content_from_ext_id("ex_id9")

      assert %{} = get_df_content_from_ext_id("ex_id9")

      assert %{
               "hierarchy_name_1" => %{"value" => ^key_node_2, "origin" => "file"},
               "hierarchy_name_2" => %{"value" => [^key_node_2, ^key_node_1], "origin" => "file"}
             } = get_df_content_from_ext_id("ex_id10")

      assert %{
               "text" => %{"value" => "URL Single url without name"},
               "urls_none_or_more" => %{
                 "value" => [
                   %{
                     "url_name" => "",
                     "url_value" => "https://www.google.es"
                   }
                 ],
                 "origin" => "file"
               }
             } = get_df_content_from_ext_id("ex_id16")

      assert %{
               "text" => %{"value" => "URL Single url with name"},
               "urls_none_or_more" => %{
                 "value" => [
                   %{"url_name" => "Google", "url_value" => "https://www.google.es"}
                 ],
                 "origin" => "file"
               }
             } = get_df_content_from_ext_id("ex_id17")

      assert %{
               "text" => %{"value" => "URL Multiple urls"},
               "urls_none_or_more" => %{
                 "value" => [
                   %{"url_name" => "Google", "url_value" => "https://www.google.es"},
                   %{
                     "url_name" => "",
                     "url_value" => "https://www.google.es"
                   },
                   %{
                     "url_name" => "",
                     "url_value" => "https://www.google.es"
                   }
                 ],
                 "origin" => "file"
               }
             } = get_df_content_from_ext_id("ex_id18")

      assert %{
               "text" => %{"value" => "URL No url"},
               "urls_none_or_more" => %{
                 "value" => [%{"url_name" => "", "url_value" => ""}],
                 "origin" => "file"
               }
             } = get_df_content_from_ext_id("ex_id19")

      assert [{:reindex, :structures, ^ids}] = IndexWorkerMock.calls()
      assert [job] = all_enqueued(worker: EmbeddingsUpsertBatch)
      assert MapSet.equal?(MapSet.new(ids), MapSet.new(job.args["data_structure_ids"]))
    end

    test "update all data structures content in native language", %{sts: sts} do
      IndexWorkerMock.clear()
      lang = "es"

      %{user_id: user_id} = build(:claims)

      structure_ids =
        sts
        |> Enum.slice(10, 14)
        |> Enum.map(& &1.data_structure_id)

      ex_id = "ex_id11"

      ex_id
      |> DataStructures.get_data_structure_by_external_id()
      |> Map.get(:id)
      |> StructureNotes.get_latest_structure_note()
      |> StructureNotes.delete_structure_note(user_id, is_bulk_update: true)

      upload = %{path: "test/fixtures/td5929/structures_in_native_lang.csv"}

      assert {contents, [] = errors} = BulkUpdate.from_csv(upload, lang)

      assert {:ok, %{update_notes: update_notes}} =
               BulkUpdate.file_bulk_update(contents, errors, user_id)

      ids = Map.keys(update_notes)
      assert length(ids) == 2
      assert Enum.all?(ids, fn id -> id in structure_ids end)

      assert %{
               "i18n_test.checkbox.fixed" => %{"value" => ["pear", "apple"], "origin" => "file"},
               "i18n_test.dropdown.fixed" => %{"value" => "peach", "origin" => "file"},
               "i18n_test.radio.fixed" => %{"value" => "apple", "origin" => "file"},
               "i18n_test_no_translate" => %{"value" => "SIN TRADUCCION", "origin" => "file"}
             } = get_df_content_from_ext_id("ex_id11")

      assert %{
               "i18n_test.checkbox.fixed" => %{"value" => ["pear", "banana"], "origin" => "file"},
               "i18n_test.dropdown.fixed" => %{"value" => "apple", "origin" => "file"},
               "i18n_test.radio.fixed" => %{"value" => "banana", "origin" => "file"},
               "i18n_test_no_translate" => %{"value" => "SIN TRADUCCION", "origin" => "file"}
             } = get_df_content_from_ext_id("ex_id12")

      assert [{:reindex, :structures, [_, _]}] = IndexWorkerMock.calls()
    end

    test "update data structures notes with values without i18n key and invalid value return error" do
      IndexWorkerMock.clear()
      lang = "es"

      %{user_id: user_id} = build(:claims)

      ex_id = "ex_id11"

      ex_id
      |> DataStructures.get_data_structure_by_external_id()
      |> Map.get(:id)
      |> StructureNotes.get_latest_structure_note()
      |> StructureNotes.delete_structure_note(user_id, is_bulk_update: true)

      upload = %{path: "test/fixtures/td5929/structures_in_native_lang_with_invalid_values.csv"}

      assert {contents, [] = errors} = BulkUpdate.from_csv(upload, lang)

      assert {:ok, %{update_notes: update_notes}} =
               BulkUpdate.file_bulk_update(contents, errors, user_id)

      [_, notes_errors] = BulkUpdate.split_succeeded_errors(update_notes)
      [note_error] = Enum.map(notes_errors, fn {_k, v} -> v end)

      assert {:error,
              {%{
                 errors: [
                   df_content:
                     {_,
                      [
                        {:"i18n_test.checkbox.fixed", {"has an invalid entry", _}},
                        {:"i18n_test.radio.fixed", {"is invalid", _}}
                      ]}
                 ]
               }, _}} = note_error

      assert [{:reindex, :structures, [_]}] = IndexWorkerMock.calls()
    end

    test "returns error on content" do
      IndexWorkerMock.clear()
      %{user_id: user_id} = build(:claims)
      user = CacheHelpers.insert_user()

      %{domain_ids: [domain_id], id: data_structure_id} =
        DataStructures.get_data_structure_by_external_id("ex_id1")

      CacheHelpers.insert_acl(domain_id, "Data Owner", [user.id])
      upload = %{path: "test/fixtures/td2942/upload_invalid.csv"}

      assert {contents, [] = errors} = BulkUpdate.from_csv(upload, @default_lang)

      assert {:ok, %{update_notes: update_notes}} =
               BulkUpdate.file_bulk_update(contents, errors, user_id)

      [_, errored_notes] = BulkUpdate.split_succeeded_errors(update_notes)

      {:error, {changeset, _data_structure}} = Map.get(errored_notes, data_structure_id)

      assert {"invalid_content", fields} = changeset.errors[:df_content]

      assert fields[:role] ==
               {"has an invalid entry", [validation: :subset, enum: [user.full_name]]}

      assert fields[:critical] ==
               {"is invalid", [validation: :inclusion, enum: ["Yes", "No"]]}

      assert fields[:integer] == :invalid_format

      assert %{"text" => %{"value" => "foo", "origin" => "user"}} =
               get_df_content_from_ext_id("ex_id1")

      assert [{:reindex, :structures, [_, _]}] = IndexWorkerMock.calls()
    end

    test "returns error on hierarchy invalid content" do
      IndexWorkerMock.clear()
      %{user_id: user_id} = build(:claims)
      upload = %{path: "test/fixtures/hierarchy/upload_invalid_hierarchy.csv"}

      assert {contents, [] = errors} = BulkUpdate.from_csv(upload, @default_lang)

      assert {:ok, %{update_notes: update_notes}} =
               BulkUpdate.file_bulk_update(contents, errors, user_id)

      [_, errored_notes] = BulkUpdate.split_succeeded_errors(update_notes)

      [first_errored_note, second_errored_note | _] =
        Enum.map(errored_notes, fn {_k, v} -> v end)

      assert {:error,
              {%{
                 errors: [
                   df_content:
                     {_,
                      [
                        hierarchy_name_2: {"hierarchy"},
                        hierarchy_name_1: {"hierarchy"}
                      ]}
                 ]
               },
               %TdDd.DataStructures.DataStructure{
                 external_id: "ex_id9"
               }}} = first_errored_note

      assert {:error,
              {%{
                 errors: [
                   df_content:
                     {_,
                      [
                        hierarchy_name_2: {"has more than one node children_2"},
                        hierarchy_name_1: {"has more than one node children_2"}
                      ]}
                 ]
               },
               %TdDd.DataStructures.DataStructure{
                 external_id: "ex_id10"
               }}} = second_errored_note

      assert [{:reindex, :structures, [_ | _]}] = IndexWorkerMock.calls()
    end

    test "returns error on dependant invalid content" do
      IndexWorkerMock.clear()

      previus_ex_id9 =
        get_df_content_from_ext_id("ex_id9")

      previus_ex_id10 =
        get_df_content_from_ext_id("ex_id10")

      %{user_id: user_id} = build(:claims)
      upload = %{path: "test/fixtures/upload_invalid_dependant.csv"}

      assert {contents, [] = errors} = BulkUpdate.from_csv(upload, @default_lang)

      assert {:ok, %{update_notes: update_notes}} =
               BulkUpdate.file_bulk_update(contents, errors, user_id)

      [_, errored_notes] =
        BulkUpdate.split_succeeded_errors(update_notes)

      [first_errored_note, second_errored_note | _] =
        Enum.map(errored_notes, fn {_k, v} -> v end)

      [first_errored_note_id, second_errored_note_id | _] =
        Enum.map(errored_notes, fn {k, _v} -> k end)

      assert {:error,
              {%{
                 errors: [
                   df_content:
                     {_,
                      [
                        son: {"is invalid", [validation: :inclusion, enum: ["b11", "b12", "b13"]]}
                      ]}
                 ]
               },
               %TdDd.DataStructures.DataStructure{
                 external_id: "ex_id9"
               }}} = first_errored_note

      assert {:error,
              {%{
                 errors: [
                   df_content:
                     {_,
                      [
                        son: {"is invalid", [validation: :inclusion, enum: ["a11", "a12", "a13"]]}
                      ]}
                 ]
               },
               %TdDd.DataStructures.DataStructure{
                 external_id: "ex_id10"
               }}} = second_errored_note

      assert previus_ex_id9 ==
               get_df_content_from_ext_id("ex_id9")

      assert previus_ex_id10 ==
               get_df_content_from_ext_id("ex_id10")

      assert [{:reindex, :structures, [first_errored_note_id, second_errored_note_id]}] ==
               IndexWorkerMock.calls()
    end

    test "create valid notes and update invalid notes using csv_bulk_update" do
      IndexWorkerMock.clear()

      previus_ex_id9 = get_df_content_from_ext_id("ex_id9")

      previus_ex_id10 = get_df_content_from_ext_id("ex_id10")

      %{user_id: user_id} = build(:claims)
      upload = %{path: "test/fixtures/upload_valid_dependant.csv"}

      assert {contents, [] = _errors} = BulkUpdate.from_csv(upload, @default_lang)

      assert {:ok, %{update_notes: update_notes}} =
               BulkUpdate.file_bulk_update(contents, [], user_id)

      [_created_notes, errored_notes] =
        BulkUpdate.split_succeeded_errors(update_notes)

      assert map_size(errored_notes) == 0

      intermediate_ex_id9 =
        get_df_content_from_ext_id("ex_id9")

      intermediate_ex_id10 =
        get_df_content_from_ext_id("ex_id10")

      assert previus_ex_id9 != intermediate_ex_id9 and
               %{
                 "father" => %{"origin" => "file", "value" => "b1"},
                 "son" => %{"origin" => "file", "value" => "b11"}
               } == intermediate_ex_id9

      assert previus_ex_id10 != intermediate_ex_id10 and
               %{
                 "father" => %{"origin" => "file", "value" => "a1"},
                 "son" => %{"origin" => "file", "value" => "a11"}
               } == intermediate_ex_id10

      assert [{:reindex, :structures, [_, _]}] = IndexWorkerMock.calls()

      IndexWorkerMock.clear()

      upload = %{path: "test/fixtures/upload_invalid_dependant.csv"}

      {contents, errors} = BulkUpdate.from_csv(upload, @default_lang)

      assert {:ok, %{update_notes: update_notes}} =
               BulkUpdate.file_bulk_update(contents, errors, user_id)

      [updated_notes, errored_notes] =
        BulkUpdate.split_succeeded_errors(update_notes)

      assert map_size(updated_notes) == 0

      [first_errored_note, second_errored_note | _] =
        Enum.map(errored_notes, fn {_k, v} -> v end)

      [first_errored_note_id, second_errored_note_id | _] =
        Enum.map(errored_notes, fn {k, _v} -> k end)

      assert {:error,
              {%{
                 errors: [
                   df_content:
                     {_,
                      [
                        son: {"is invalid", [validation: :inclusion, enum: ["b11", "b12", "b13"]]}
                      ]}
                 ]
               },
               %TdDd.DataStructures.DataStructure{
                 external_id: "ex_id9"
               }}} = first_errored_note

      assert {:error,
              {%{
                 errors: [
                   df_content:
                     {_,
                      [
                        son: {"is invalid", [validation: :inclusion, enum: ["a11", "a12", "a13"]]}
                      ]}
                 ]
               },
               %TdDd.DataStructures.DataStructure{
                 external_id: "ex_id10"
               }}} = second_errored_note

      assert intermediate_ex_id9 ==
               get_df_content_from_ext_id("ex_id9")

      assert intermediate_ex_id10 ==
               get_df_content_from_ext_id("ex_id10")

      assert [{:reindex, :structures, [^first_errored_note_id, ^second_errored_note_id]}] =
               IndexWorkerMock.calls()
    end

    test "accept file utf8 with bom" do
      IndexWorkerMock.clear()
      %{user_id: user_id} = build(:claims)
      upload = %{path: "test/fixtures/td3606/upload_with_bom.csv"}

      assert {contents, [] = errors} = BulkUpdate.from_csv(upload, @default_lang)

      assert {:ok, %{update_notes: _update_notes}} =
               BulkUpdate.file_bulk_update(contents, errors, user_id)

      assert [{:reindex, :structures, ids_reindex}] = IndexWorkerMock.calls()
      assert length(ids_reindex) == 9
    end

    test "return error when external_id column does not exists" do
      upload = %{path: "test/fixtures/td3606/upload_without_external_id.csv"}

      assert {:error, %{message: :external_id_not_found}} =
               BulkUpdate.from_csv(upload, @default_lang)
    end

    test "return error when all external_id are invalid" do
      IndexWorkerMock.clear()

      upload = %{path: "test/fixtures/td7294/upload_all_invalid_ext_id.csv"}

      assert {:error, %{message: :external_id_not_found}} =
               BulkUpdate.from_csv(upload, @default_lang)
    end

    test "upload valid notes when some external_id does not exist and there are duplicates", %{
      sts: sts
    } do
      IndexWorkerMock.clear()

      %{user_id: user_id} = build(:claims)

      structure_ids = Enum.map(sts, & &1.data_structure_id)

      %{domain_ids: [domain_id]} = DataStructures.get_data_structure_by_external_id("ex_id1")

      user_ids =
        Enum.map(["Role", "Role 1", "Role 2"], fn full_name ->
          CacheHelpers.insert_user(full_name: full_name).id
        end)

      CacheHelpers.insert_acl(domain_id, "Data Owner", user_ids)

      upload = %{path: "test/fixtures/td7294/upload_with_duplicates_and_invalid_ext_id.csv"}

      assert {contents, [_ | _] = errors} = BulkUpdate.from_csv(upload, @default_lang)

      assert {:ok,
              %{
                update_notes: update_notes,
                split_duplicates: {_unique_contents, duplicate_errors}
              }} =
               BulkUpdate.file_bulk_update(contents, errors, user_id)

      assert errors == [
               %{
                 message: "external_id_not_found",
                 external_id: "ex_id_invalid",
                 row: 3,
                 sheet: nil
               },
               %{
                 message: "external_id_not_found",
                 external_id: "ex_id_invalid_2",
                 row: 8,
                 sheet: nil
               }
             ]

      assert duplicate_errors == [
               %{message: "duplicate", external_id: "ex_id3", row: 7, sheet: nil},
               %{message: "duplicate", external_id: "ex_id2", row: 6, sheet: nil}
             ]

      updated_ids = Map.keys(update_notes)

      assert length(updated_ids) == 3

      assert Enum.all?(updated_ids, fn id -> id in structure_ids end)

      assert %{
               "text" => %{"value" => "text", "origin" => "file"},
               "critical" => %{"value" => "Yes", "origin" => "file"},
               "role" => %{"value" => ["Role", "Role 1"], "origin" => "file"},
               "key_value" => %{"value" => [""], "origin" => "file"}
             } = get_df_content_from_ext_id("ex_id1")

      assert %{
               "text" => %{"value" => "text2", "origin" => "file"},
               "critical" => %{"value" => "Yes", "origin" => "file"},
               "role" => %{"value" => ["Role"], "origin" => "file"}
             } = get_df_content_from_ext_id("ex_id2")

      assert %{
               "text" => %{"value" => "foo", "origin" => "user"},
               "critical" => %{"value" => "No", "origin" => "file"},
               "role" => %{"value" => ["Role 2"], "origin" => "file"}
             } = get_df_content_from_ext_id("ex_id3")

      assert [{:reindex, :structures, ^updated_ids}] = IndexWorkerMock.calls()
    end
  end

  describe "structure notes" do
    test "bulk upload notes of data structures with no previous notes", %{type: type} do
      IndexWorkerMock.clear()

      %{user_id: user_id} = claims = build(:claims)

      note = %{
        "string" => %{"value" => "bar", "origin" => "file"},
        "list" => %{"value" => "two", "origin" => "file"}
      }

      structure_count = 5

      data_structure_ids =
        1..structure_count
        |> Enum.map(fn _ -> valid_structure(type) end)
        |> Enum.map(& &1.data_structure_id)

      BulkUpdate.update_all(data_structure_ids, %{"df_content" => note}, claims, false)

      structure_notes = Enum.map(data_structure_ids, &StructureNotes.list_structure_notes/1)

      df_contents =
        structure_notes
        |> Enum.filter(&(Enum.count(&1) == 1))
        |> Enum.map(&Enum.at(&1, -1).df_content)

      last_changed_by =
        structure_notes
        |> Enum.filter(&(Enum.count(&1) == 1))
        |> Enum.map(&Enum.at(&1, -1).last_changed_by)

      assert Enum.count(df_contents) == structure_count
      Enum.each(df_contents, fn df_content -> assert df_content == note end)
      assert Enum.all?(last_changed_by, &(&1 == user_id))
      assert [{:reindex, :structures, ids_reindex}] = IndexWorkerMock.calls()
      assert length(ids_reindex) == structure_count
    end

    test "bulk upload notes of data structures with draft notes", %{type: type} do
      IndexWorkerMock.clear()

      note = %{
        "string" => %{"value" => "bar", "origin" => "file"},
        "list" => %{"value" => "two", "origin" => "file"}
      }

      structure_count = 5

      data_structure_ids =
        1..structure_count
        |> Enum.map(fn _ -> valid_structure(type) end)
        |> Enum.map(&insert(:structure_note, data_structure: &1.data_structure))
        |> Enum.map(& &1.data_structure_id)

      BulkUpdate.update_all(data_structure_ids, %{"df_content" => note}, build(:claims), false)

      df_contents =
        data_structure_ids
        |> Enum.map(&StructureNotes.list_structure_notes/1)
        |> Enum.filter(&(Enum.count(&1) == 1))
        |> Enum.map(&Enum.at(&1, -1).df_content)

      assert Enum.count(df_contents) == structure_count
      Enum.each(df_contents, fn df_content -> assert df_content == note end)
      assert [{:reindex, :structures, ids_reindex}] = IndexWorkerMock.calls()
      assert length(ids_reindex) == structure_count
    end

    test "bulk upload notes of data structures with published notes", %{type: type} do
      IndexWorkerMock.clear()

      note = %{
        "string" => %{"value" => "bar", "origin" => "file"},
        "list" => %{"value" => "two", "origin" => "file"}
      }

      structure_count = 5

      data_structure_ids =
        1..structure_count
        |> Enum.map(fn _ -> valid_structure(type) end)
        |> Enum.map(
          &insert(:structure_note, status: :published, data_structure: &1.data_structure)
        )
        |> Enum.map(& &1.data_structure_id)

      BulkUpdate.update_all(data_structure_ids, %{"df_content" => note}, build(:claims), false)

      df_contents =
        data_structure_ids
        |> Enum.map(&StructureNotes.list_structure_notes/1)
        |> Enum.filter(&(Enum.count(&1) == 2))
        |> Enum.map(&Enum.at(&1, -1).df_content)

      assert Enum.count(df_contents) == structure_count
      Enum.each(df_contents, fn df_content -> assert df_content == note end)
      assert [{:reindex, :structures, ids_reindex}] = IndexWorkerMock.calls()
      assert length(ids_reindex) == structure_count
    end

    test "bulk upload notes when a data structure is duplicated ", %{type: type} do
      IndexWorkerMock.clear()

      note = %{
        "string" => %{"value" => "bar", "origin" => "file"},
        "list" => %{"value" => "two", "origin" => "file"}
      }

      struct_published_note = valid_structure(type)

      insert(:structure_note,
        status: :published,
        data_structure: struct_published_note.data_structure
      )

      struct_draft_note = valid_structure(type)
      insert(:structure_note, data_structure: struct_draft_note.data_structure)

      struct_no_note = valid_structure(type)

      data_structure_ids = [
        struct_published_note.data_structure_id,
        struct_draft_note.data_structure_id,
        struct_no_note.data_structure_id,
        struct_published_note.data_structure_id,
        struct_draft_note.data_structure_id,
        struct_no_note.data_structure_id
      ]

      assert {:ok, _} =
               BulkUpdate.update_all(
                 data_structure_ids,
                 %{"df_content" => note},
                 build(:claims),
                 false
               )

      df_contents = Enum.map(data_structure_ids, &StructureNotes.list_structure_notes/1)

      df_contents_published =
        df_contents
        |> Enum.filter(&(Enum.count(&1) == 2))
        |> Enum.map(&Enum.at(&1, -1).df_content)

      df_contents_non_published =
        df_contents
        |> Enum.filter(&(Enum.count(&1) == 1))
        |> Enum.map(&Enum.at(&1, -1).df_content)

      assert Enum.count(df_contents_published) == 2
      assert Enum.count(df_contents_non_published) == 4
      Enum.each(df_contents_published, fn df_content -> assert df_content == note end)
      Enum.each(df_contents_non_published, fn df_content -> assert df_content == note end)
      assert [{:reindex, :structures, ids_reindex}] = IndexWorkerMock.calls()
      assert length(ids_reindex) == length(Enum.uniq(data_structure_ids))
    end
  end

  defp invalid_structure do
    insert(:data_structure_version,
      type: "missing_type",
      data_structure: build(:data_structure, external_id: "the bad one")
    )
  end

  defp valid_structure(type, ds_opts \\ []) do
    insert(:data_structure_version,
      type: type,
      data_structure: build(:data_structure, ds_opts)
    )
  end

  defp valid_structure_note(type, sn_opts) do
    data_structure = insert(:data_structure)
    valid_structure_note(type, data_structure, sn_opts)
  end

  defp valid_structure_note(type, data_structure, sn_opts) do
    insert(:data_structure_version,
      type: type,
      data_structure: data_structure
    )

    insert(:structure_note, [data_structure: data_structure] ++ sn_opts)
  end

  defp from_csv_templates(_) do
    %{id: id_t1, name: type1} = CacheHelpers.insert_template(content: @c1)
    %{id: id_t2, name: type2} = CacheHelpers.insert_template(content: @c2)
    %{id: id_t3, name: type3} = CacheHelpers.insert_template(content: @c3)

    %{id: url_template_id, name: url_template_name} =
      CacheHelpers.insert_template(content: @url_template)

    domain = CacheHelpers.insert_domain()

    insert(:data_structure_type, name: type1, template_id: id_t1)
    insert(:data_structure_type, name: type2, template_id: id_t2)
    insert(:data_structure_type, name: type3, template_id: id_t3)
    insert(:data_structure_type, name: url_template_name, template_id: url_template_id)

    sts1 =
      Enum.map(1..5, fn id ->
        data_structure =
          insert(:data_structure, external_id: "ex_id#{id}", domain_ids: [domain.id])

        valid_structure_note(type1, data_structure,
          df_content: %{"text" => %{"value" => "foo", "origin" => "user"}}
        )
      end)

    sts2 =
      Enum.map(6..10, fn id ->
        data_structure = insert(:data_structure, external_id: "ex_id#{id}")

        valid_structure_note(type2, data_structure, [])
      end)

    sts3 =
      Enum.map(11..15, fn id ->
        data_structure = insert(:data_structure, external_id: "ex_id#{id}")
        opts = if Integer.mod(id, 2) !== 0, do: [], else: [status: :draft]
        valid_structure_note(type3, data_structure, opts)
      end)

    url_sts =
      Enum.map(16..19, fn id ->
        data_structure = insert(:data_structure, external_id: "ex_id#{id}")

        valid_structure_note(url_template_name, data_structure, [])
      end)

    [sts: sts1 ++ sts2 ++ sts3 ++ url_sts]
  end

  defp insert_i18n_messages(_) do
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
  end

  defp to_enriched_text(text) do
    %{
      "document" => %{
        "nodes" => [
          %{
            "nodes" => [
              %{"leaves" => [%{"text" => text}], "object" => "text"}
            ],
            "object" => "block",
            "type" => "paragraph"
          }
        ]
      }
    }
  end

  defp create_hierarchy do
    hierarchy_id = 1

    %{
      id: hierarchy_id,
      name: "name_#{hierarchy_id}",
      nodes: [
        build(:hierarchy_node, %{
          node_id: 1,
          parent_id: nil,
          name: "father",
          path: "/father",
          hierarchy_id: hierarchy_id
        }),
        build(:hierarchy_node, %{
          node_id: 2,
          parent_id: 1,
          name: "children_1",
          path: "/father/children_1",
          hierarchy_id: hierarchy_id
        }),
        build(:hierarchy_node, %{
          node_id: 3,
          parent_id: 1,
          name: "children_2",
          path: "/father/children_2",
          hierarchy_id: hierarchy_id
        }),
        build(:hierarchy_node, %{
          node_id: 4,
          parent_id: nil,
          name: "children_2",
          path: "/children_2",
          hierarchy_id: hierarchy_id
        })
      ]
    }
  end
end
