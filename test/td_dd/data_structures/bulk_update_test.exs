defmodule TdDd.DataStructures.BulkUpdateTest do
  use TdDd.DataCase

  import Mox
  import TdDd.TestOperators

  alias TdCore.Search.IndexWorker
  alias TdDd.DataStructures
  alias TdDd.DataStructures.BulkUpdate
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
          "cardinality" => "*",
          "label" => "Urls One Or None",
          "name" => "urls_one_or_none",
          "type" => "url",
          "values" => nil,
          "widget" => "pair_list"
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
          "type" => "hierarchy",
          "values" => %{"hierarchy" => %{"id" => 1}},
          "widget" => "dropdown"
        },
        %{
          "cardinality" => "*",
          "name" => "hierarchy_name_2",
          "type" => "hierarchy",
          "values" => %{"hierarchy" => %{"id" => 1}},
          "widget" => "dropdown"
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
  @default_lang "en"

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup do
    start_supervised!(TdDd.Search.StructureEnricher)

    %{id: template_id, name: template_name} = template = CacheHelpers.insert_template()
    CacheHelpers.insert_structure_type(name: template_name, template_id: template_id)
    hierarchy = create_hierarchy()
    CacheHelpers.insert_hierarchy(hierarchy)

    IndexWorker.clear()

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
      IndexWorker.clear()
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
               BulkUpdate.update_all(ids, @valid_params, claims, false)

      assert Map.keys(update_notes) ||| ids

      assert ids
             |> Enum.map(&StructureNotes.get_latest_structure_note/1)
             |> Enum.map(& &1.df_content)
             |> Enum.all?(&(&1 == @valid_content))

      assert [{:reindex, :structures, ids_reindex}] = IndexWorker.calls()
      assert length(ids_reindex) == length(ids)
    end

    test "update and publish all data structures with valid data", %{type: type} do
      IndexWorker.clear()
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

      assert [{:reindex, :structures, ^ids}] = IndexWorker.calls()
    end

    test "update and republish only data structures with different valid data", %{type: type} do
      IndexWorker.clear()
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
               IndexWorker.calls()

      assert length(ids_reindex_1) == 10
      assert length(ids_reindex_2) == 10
    end

    test "ignores unchanged data structures", %{type: type} do
      IndexWorker.clear()
      claims = build(:claims)
      fixed_datetime = ~N[2020-01-01 00:00:00]
      timestamps = [inserted_at: fixed_datetime, updated_at: fixed_datetime]

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
            ] ++ timestamps
          )
        end)
        |> Enum.map(& &1.data_structure_id)

      unchanged_ids =
        1..5
        |> Enum.map(fn _ ->
          valid_structure_note(type, [df_content: @valid_content] ++ timestamps)
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
      assert [{:reindex, :structures, ids_reindex}] = IndexWorker.calls()
      assert length(ids_reindex) == length(ids)
    end

    test "returns an error if a structure has no template", %{type: type} do
      IndexWorker.clear()
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
      assert [{:reindex, :structures, ids_reindex}] = IndexWorker.calls()
      assert length(ids_reindex) == 10
    end

    test "only updates specified fields", %{type: type} do
      IndexWorker.clear()
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

      assert [{:reindex, :structures, ids_reindex}] = IndexWorker.calls()
      assert length(ids_reindex) == structure_count
    end

    test "only updates specified fields for published notes", %{type: type} do
      IndexWorker.clear()
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

      assert [{:reindex, :structures, ids_reindex}] = IndexWorker.calls()
      assert length(ids_reindex) == structure_count
    end

    test "when bulk updating will allow to create templates with missing required fields", %{
      type: type
    } do
      IndexWorker.clear()
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

      assert [{:reindex, :structures, ids_reindex}] = IndexWorker.calls()
      assert length(ids_reindex) == structure_count
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
      IndexWorker.clear()
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

      assert [{:reindex, :structures, ids_reindex}] = IndexWorker.calls()
      assert length(ids_reindex) == structure_count
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
      IndexWorker.clear()
      [%{key: key_node_1}, %{key: key_node_2} | _] = nodes

      %{user_id: user_id} = build(:claims)
      structure_ids = Enum.map(sts, & &1.data_structure_id)

      ["ex_id1", "ex_id6"]
      |> Enum.each(fn ex_id ->
        ex_id
        |> DataStructures.get_data_structure_by_external_id()
        |> Map.get(:id)
        |> StructureNotes.get_latest_structure_note()
        |> StructureNotes.delete_structure_note(user_id)
      end)

      %{domain_ids: [domain_id]} = DataStructures.get_data_structure_by_external_id("ex_id1")

      user_ids =
        Enum.map(["Role", "Role 1", "Role 2"], fn full_name ->
          CacheHelpers.insert_user(full_name: full_name).id
        end)

      CacheHelpers.insert_acl(domain_id, "Data Owner", user_ids)
      upload = %{path: "test/fixtures/td2942/upload.csv"}

      assert {:ok, %{update_notes: update_notes}} =
               upload
               |> BulkUpdate.from_csv(@default_lang)
               |> BulkUpdate.do_csv_bulk_update(user_id)

      ids = Map.keys(update_notes)
      assert length(ids) == 10
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
      url = to_content_url("https://www.google.es")

      assert %{
               "enriched_text" => %{"value" => ^text, "origin" => "file"},
               "urls_one_or_none" => %{"value" => ^url, "origin" => "file"},
               "integer" => %{"value" => 3, "origin" => "file"}
             } = get_df_content_from_ext_id("ex_id7")

      assert %{
               "urls_one_or_none" => %{"value" => ^url, "origin" => "file"},
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
               "hierarchy_name_2" => %{"value" => [^key_node_2, ^key_node_1], "origin" => "file"},
               "urls_one_or_none" => %{"value" => _, "origin" => "file"}
             } = get_df_content_from_ext_id("ex_id10")

      assert [{:reindex, :structures, ^ids}] = IndexWorker.calls()
    end

    test "update all data structures content in native language", %{sts: sts} do
      IndexWorker.clear()
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
      |> StructureNotes.delete_structure_note(user_id)

      upload = %{path: "test/fixtures/td5929/structures_in_native_lang.csv"}

      assert {:ok, %{update_notes: update_notes}} =
               upload
               |> BulkUpdate.from_csv(lang)
               |> BulkUpdate.do_csv_bulk_update(user_id)

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

      assert [{:reindex, :structures, [_, _]}] = IndexWorker.calls()
    end

    test "update data structures notes with values without i18n key and invalid value return error" do
      IndexWorker.clear()
      lang = "es"

      %{user_id: user_id} = build(:claims)

      ex_id = "ex_id11"

      ex_id
      |> DataStructures.get_data_structure_by_external_id()
      |> Map.get(:id)
      |> StructureNotes.get_latest_structure_note()
      |> StructureNotes.delete_structure_note(user_id)

      upload = %{path: "test/fixtures/td5929/structures_in_native_lang_with_invalid_values.csv"}

      assert {:ok, %{update_notes: update_notes}} =
               upload
               |> BulkUpdate.from_csv(lang)
               |> BulkUpdate.do_csv_bulk_update(user_id)

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

      assert [{:reindex, :structures, [_]}] = IndexWorker.calls()
    end

    test "returns error on content" do
      IndexWorker.clear()
      %{user_id: user_id} = build(:claims)
      user = CacheHelpers.insert_user()

      %{domain_ids: [domain_id], id: data_structure_id} =
        DataStructures.get_data_structure_by_external_id("ex_id1")

      CacheHelpers.insert_acl(domain_id, "Data Owner", [user.id])
      upload = %{path: "test/fixtures/td2942/upload_invalid.csv"}

      {:ok, %{update_notes: update_notes}} =
        upload
        |> BulkUpdate.from_csv(@default_lang)
        |> BulkUpdate.do_csv_bulk_update(user_id)

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

      assert [{:reindex, :structures, [_, _]}] = IndexWorker.calls()
    end

    test "returns error on hierarchy invalid content" do
      IndexWorker.clear()
      %{user_id: user_id} = build(:claims)
      upload = %{path: "test/fixtures/hierarchy/upload_invalid_hierarchy.csv"}

      {:ok, %{update_notes: update_notes}} =
        upload
        |> BulkUpdate.from_csv(@default_lang)
        |> BulkUpdate.do_csv_bulk_update(user_id)

      [_, errored_notes] = BulkUpdate.split_succeeded_errors(update_notes)

      [first_errored_note | _] = Enum.map(errored_notes, fn {_k, v} -> v end)

      assert {:error,
              {%{
                 errors: [
                   df_content:
                     {_,
                      [
                        hierarchy_name_1: {"has more than one node children_2"},
                        hierarchy_name_2: {"has more than one node children_2"}
                      ]}
                 ]
               }, _}} = first_errored_note

      assert [{:reindex, :structures, [_]}] = IndexWorker.calls()
    end

    test "accept file utf8 with bom" do
      IndexWorker.clear()
      %{user_id: user_id} = build(:claims)
      upload = %{path: "test/fixtures/td3606/upload_with_bom.csv"}

      assert {:ok, %{update_notes: _update_notes}} =
               upload
               |> BulkUpdate.from_csv(@default_lang)
               |> BulkUpdate.do_csv_bulk_update(user_id)

      assert [{:reindex, :structures, ids_reindex}] = IndexWorker.calls()
      assert length(ids_reindex) == 9
    end

    test "return error when external_id does not exists" do
      upload = %{path: "test/fixtures/td3606/upload_without_external_id.csv"}

      assert {:error, %{message: :external_id_not_found}} =
               BulkUpdate.from_csv(upload, @default_lang)
    end
  end

  describe "structure notes" do
    test "bulk upload notes of data structures with no previous notes", %{type: type} do
      IndexWorker.clear()

      note = %{
        "string" => %{"value" => "bar", "origin" => "file"},
        "list" => %{"value" => "two", "origin" => "file"}
      }

      structure_count = 5

      data_structure_ids =
        1..structure_count
        |> Enum.map(fn _ -> valid_structure(type) end)
        |> Enum.map(& &1.data_structure_id)

      BulkUpdate.update_all(data_structure_ids, %{"df_content" => note}, build(:claims), false)

      df_contents =
        data_structure_ids
        |> Enum.map(&StructureNotes.list_structure_notes/1)
        |> Enum.filter(&(Enum.count(&1) == 1))
        |> Enum.map(&Enum.at(&1, -1).df_content)

      assert Enum.count(df_contents) == structure_count
      Enum.each(df_contents, fn df_content -> assert df_content == note end)
      assert [{:reindex, :structures, ids_reindex}] = IndexWorker.calls()
      assert length(ids_reindex) == 5
    end

    test "bulk upload notes of data structures with draft notes", %{type: type} do
      IndexWorker.clear()

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
      assert [{:reindex, :structures, ids_reindex}] = IndexWorker.calls()
      assert length(ids_reindex) == structure_count
    end

    test "bulk upload notes of data structures with published notes", %{type: type} do
      IndexWorker.clear()

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
      assert [{:reindex, :structures, ids_reindex}] = IndexWorker.calls()
      assert length(ids_reindex) == structure_count
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
    domain = CacheHelpers.insert_domain()

    insert(:data_structure_type, name: type1, template_id: id_t1)
    insert(:data_structure_type, name: type2, template_id: id_t2)
    insert(:data_structure_type, name: type3, template_id: id_t3)

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

    [sts: sts1 ++ sts2 ++ sts3]
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

  defp to_content_url(url) do
    [%{"url_name" => url, "url_value" => url}]
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
