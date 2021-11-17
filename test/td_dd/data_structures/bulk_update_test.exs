defmodule TdDd.DataStructures.BulkUpdateTest do
  use TdDd.DataCase

  import TdDd.TestOperators

  alias TdDd.DataStructures
  alias TdDd.DataStructures.BulkUpdate

  @moduletag sandbox: :shared
  @valid_content %{"string" => "present", "list" => "one"}
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
          "default" => "",
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
          "type" => "user"
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
        }
      ]
    }
  ]

  setup do
    %{id: template_id, name: template_name} = template = CacheHelpers.insert_template()
    CacheHelpers.insert_structure_type(name: template_name, template_id: template_id)

    start_supervised!(TdDd.Search.StructureEnricher)
    [template: template, type: template_name]
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
      claims = build(:claims)

      ids =
        1..10
        |> Enum.map(fn _ -> valid_structure_note(type, df_content: %{"string" => "foo"}) end)
        |> Enum.map(& &1.data_structure_id)

      assert {:ok, %{update_notes: update_notes}} =
               BulkUpdate.update_all(ids, @valid_params, claims, false)

      assert Map.keys(update_notes) <|> ids

      assert ids
             |> Enum.map(&DataStructures.get_latest_structure_note/1)
             |> Enum.map(& &1.df_content)
             |> Enum.all?(&(&1 == @valid_content))
    end

    test "update and publish all data structures with valid data", %{type: type} do
      claims = build(:claims)

      ids =
        1..10
        |> Enum.map(fn _ -> valid_structure_note(type, df_content: %{"string" => "foo"}) end)
        |> Enum.map(& &1.data_structure_id)

      assert {:ok, %{update_notes: update_notes}} =
               BulkUpdate.update_all(ids, @valid_params, claims, true)

      assert Map.keys(update_notes) <|> ids

      latest_structure_notes = Enum.map(ids, &DataStructures.get_latest_structure_note/1)

      assert latest_structure_notes
             |> Enum.map(& &1.df_content)
             |> Enum.all?(&(&1 == @valid_content))

      assert latest_structure_notes
             |> Enum.map(& &1.status)
             |> Enum.all?(&(&1 == :published))
    end

    test "ignores unchanged data structures", %{type: type} do
      claims = build(:claims)
      fixed_datetime = ~N[2020-01-01 00:00:00]
      timestamps = [inserted_at: fixed_datetime, updated_at: fixed_datetime]

      changed_ids =
        1..5
        |> Enum.map(fn _ ->
          valid_structure_note(
            type,
            [df_content: %{"string" => "foo", "list" => "bar"}] ++ timestamps
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
        ids |> Enum.map(&DataStructures.list_structure_notes/1) |> Enum.map(&Enum.at(&1, -1))

      changed_notes_ds_ids =
        notes
        |> Enum.reject(&(&1.updated_at == &1.inserted_at))
        |> Enum.map(& &1.data_structure_id)

      assert notes
             |> Enum.map(& &1.df_content)
             |> Enum.all?(&(&1 == @valid_content))

      assert Enum.count(changed_notes_ds_ids) == 5
      assert changed_notes_ds_ids <|> changed_ids
    end

    test "returns an error if a structure has no template", %{type: type} do
      claims = build(:claims)
      content = %{"string" => "foo", "list" => "bar"}

      ids =
        1..10
        |> Enum.map(fn
          9 -> invalid_structure()
          _ -> valid_structure_note(type, df_content: content)
        end)
        |> Enum.map(& &1.data_structure_id)

      assert {:error, :update_notes, changeset, _changes_so_far} =
               BulkUpdate.update_all(ids, @valid_params, claims, false)

      assert {%{errors: errors}, data_structure} = changeset
      assert %{external_id: "the bad one"} = data_structure
      assert {"missing_type", _} = errors[:df_content]
    end

    test "only updates specified fields", %{type: type} do
      claims = build(:claims)

      initial_content = Map.replace!(@valid_content, "string", "initial")

      structure_count = 10

      ids =
        1..structure_count
        |> Enum.map(fn _ -> valid_structure_note(type, df_content: initial_content) end)
        |> Enum.map(& &1.data_structure_id)

      assert {:ok, %{update_notes: update_notes}} =
               BulkUpdate.update_all(
                 ids,
                 %{"df_content" => %{"string" => "updated"}},
                 claims,
                 false
               )

      assert Map.keys(update_notes) <|> ids

      df_contents =
        ids
        |> Enum.map(&DataStructures.list_structure_notes/1)
        |> Enum.filter(&(Enum.count(&1) == 1))
        |> Enum.map(&Enum.at(&1, -1).df_content)

      assert Enum.count(df_contents) == structure_count

      Enum.each(df_contents, fn df_content ->
        assert df_content == %{"string" => "updated", "list" => initial_content["list"]}
      end)
    end

    test "only updates specified fields for published notes", %{type: type} do
      claims = build(:claims)
      structure_count = 10

      ids =
        1..structure_count
        |> Enum.map(fn _ ->
          insert(:data_structure_version,
            type: type
          )
        end)
        |> Enum.map(& &1.data_structure_id)

      assert {:ok, %{update_notes: update_notes}} =
               BulkUpdate.update_all(
                 ids,
                 %{"df_content" => %{"string" => "updated"}},
                 claims,
                 false
               )

      assert Map.keys(update_notes) <|> ids

      df_contents =
        Enum.map(ids, fn id ->
          id
          |> DataStructures.get_latest_structure_note()
          |> Map.get(:df_content)
        end)

      assert Enum.count(df_contents) == structure_count

      Enum.each(df_contents, fn df_content ->
        assert df_content == %{"string" => "updated"}
      end)
    end

    test "when bulk updating will allow to create templates with missing required fields", %{
      type: type
    } do
      claims = build(:claims)

      initial_content = Map.replace!(@valid_content, "string", "initial")

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
                 %{"df_content" => %{"string" => "updated"}},
                 claims,
                 false
               )

      assert Map.keys(update_notes) <|> ids

      df_contents =
        Enum.map(ids, fn id ->
          id
          |> DataStructures.get_latest_structure_note()
          |> Map.get(:df_content)
        end)

      assert Enum.count(df_contents) == structure_count

      Enum.each(df_contents, fn df_content ->
        assert df_content == %{"string" => "updated", "list" => initial_content["list"]}
      end)
    end

    test "only validates specified fields", %{type: type} do
      claims = build(:claims)

      id = valid_structure_note(type, df_content: %{"list" => "two"}).data_structure_id

      assert {:ok, %{update_notes: _update_notes}} =
               BulkUpdate.update_all([id], %{"df_content" => %{"list" => "one"}}, claims, false)

      %{df_content: df_content} =
        id
        |> DataStructures.get_latest_structure_note()

      assert df_content == %{"list" => "one"}
    end

    test "ignores empty fields", %{type: type} do
      claims = build(:claims)

      initial_content = Map.replace!(@valid_content, "string", "initial")

      structure_count = 10

      ids =
        1..structure_count
        |> Enum.map(fn _ -> valid_structure_note(type, df_content: initial_content) end)
        |> Enum.map(& &1.data_structure_id)

      assert {:ok, %{update_notes: update_notes}} =
               BulkUpdate.update_all(
                 ids,
                 %{"df_content" => %{"string" => "", "list" => "two"}},
                 claims,
                 false
               )

      assert Map.keys(update_notes) <|> ids

      df_contents =
        ids
        |> Enum.map(&DataStructures.list_structure_notes/1)
        |> Enum.filter(&(Enum.count(&1) == 1))
        |> Enum.map(&Enum.at(&1, -1).df_content)

      assert Enum.count(df_contents) == structure_count

      Enum.each(df_contents, fn df_content ->
        assert df_content == %{"string" => initial_content["string"], "list" => "two"}
      end)
    end
  end

  describe "from_csv/2" do
    setup :from_csv_templates

    defp get_df_content_from_ext_id(ext_id) do
      ext_id
      |> DataStructures.get_data_structure_by_external_id()
      |> Map.get(:id)
      |> DataStructures.get_latest_structure_note()
      |> Map.get(:df_content)
    end

    test "update all data structures content", %{sts: sts} do
      %{user_id: user_id} = build(:claims)
      structure_ids = Enum.map(sts, & &1.data_structure_id)

      ["ex_id1", "ex_id6"]
      |> Enum.each(fn ex_id ->
        ex_id
        |> DataStructures.get_data_structure_by_external_id()
        |> Map.get(:id)
        |> DataStructures.get_latest_structure_note()
        |> DataStructures.delete_structure_note(user_id)
      end)

      upload = %{path: "test/fixtures/td2942/upload.csv"}

      assert {:ok, %{update_notes: update_notes}} =
               upload
               |> BulkUpdate.from_csv()
               |> BulkUpdate.do_csv_bulk_update(user_id)

      ids = Map.keys(update_notes)
      assert length(ids) == 9
      assert Enum.all?(ids, fn id -> id in structure_ids end)

      assert %{"text" => "text", "critical" => "Yes", "role" => ["Role"], "key_value" => ["1"]} =
               get_df_content_from_ext_id("ex_id1")

      assert %{"text" => "text2", "critical" => "Yes", "role" => ["Role"]} =
               get_df_content_from_ext_id("ex_id2")

      assert %{"text" => "foo", "critical" => "No", "role" => ["Role"]} =
               get_df_content_from_ext_id("ex_id3")

      assert %{"text" => "foo", "critical" => "No", "role" => ["Role 1"]} =
               get_df_content_from_ext_id("ex_id4")

      assert %{"text" => "foo", "critical" => "No", "role" => ["Role 2"], "key_value" => ["2"]} =
               get_df_content_from_ext_id("ex_id5")

      text = to_enriched_text("I’m 6")

      assert %{"enriched_text" => ^text} = get_df_content_from_ext_id("ex_id6")

      text = to_enriched_text("Enriched text")
      url = to_content_url("https://www.google.es")

      assert %{"enriched_text" => ^text, "urls_one_or_none" => ^url, "integer" => 3} =
               get_df_content_from_ext_id("ex_id7")

      assert %{"urls_one_or_none" => ^url, "integer" => 2} = get_df_content_from_ext_id("ex_id8")

      text = to_enriched_text("I’m 9")

      assert %{"enriched_text" => ^text, "integer" => 9} = get_df_content_from_ext_id("ex_id9")

      assert %{} = get_df_content_from_ext_id("ex_id9")
    end

    test "returns error on content" do
      %{user_id: user_id} = build(:claims)
      upload = %{path: "test/fixtures/td2942/upload_invalid.csv"}

      assert {:error, :update_notes,
              {%{errors: [df_content: {_, [critical: {_, validation}]}]}, _},
              _} =
               upload
               |> BulkUpdate.from_csv()
               |> BulkUpdate.do_csv_bulk_update(user_id)

      assert Keyword.get(validation, :validation) == :inclusion
      assert Keyword.get(validation, :enum) == ["Yes", "No"]

      assert %{"text" => "foo"} = get_df_content_from_ext_id("ex_id1")
    end

    test "accept file utf8 wiht bom" do
      %{user_id: user_id} = build(:claims)
      upload = %{path: "test/fixtures/td3606/upload_with_bom.csv"}

      assert {:ok, %{update_notes: _update_notes}} =
               upload
               |> BulkUpdate.from_csv()
               |> BulkUpdate.do_csv_bulk_update(user_id)
    end

    test "return error when external_id does not exists" do
      upload = %{path: "test/fixtures/td3606/upload_without_external_id.csv"}

      assert {:error, %{message: :external_id_not_found}} =
               upload
               |> BulkUpdate.from_csv()
    end
  end

  describe "structure notes" do
    test "bulk upload notes of data structures with no previous notes", %{type: type} do
      note = %{"string" => "bar", "list" => "two"}

      structure_count = 5

      data_structure_ids =
        1..structure_count
        |> Enum.map(fn _ -> valid_structure(type) end)
        |> Enum.map(& &1.data_structure_id)

      BulkUpdate.update_all(data_structure_ids, %{"df_content" => note}, build(:claims), false)

      df_contents =
        data_structure_ids
        |> Enum.map(&DataStructures.list_structure_notes/1)
        |> Enum.filter(&(Enum.count(&1) == 1))
        |> Enum.map(&Enum.at(&1, -1).df_content)

      assert Enum.count(df_contents) == structure_count
      Enum.each(df_contents, fn df_content -> assert df_content == note end)
    end

    test "bulk upload notes of data structures with draft notes", %{type: type} do
      note = %{"string" => "bar", "list" => "two"}

      structure_count = 5

      data_structure_ids =
        1..structure_count
        |> Enum.map(fn _ -> valid_structure(type) end)
        |> Enum.map(&insert(:structure_note, data_structure: &1.data_structure))
        |> Enum.map(& &1.data_structure_id)

      BulkUpdate.update_all(data_structure_ids, %{"df_content" => note}, build(:claims), false)

      df_contents =
        data_structure_ids
        |> Enum.map(&DataStructures.list_structure_notes/1)
        |> Enum.filter(&(Enum.count(&1) == 1))
        |> Enum.map(&Enum.at(&1, -1).df_content)

      assert Enum.count(df_contents) == structure_count
      Enum.each(df_contents, fn df_content -> assert df_content == note end)
    end

    test "bulk upload notes of data structures with published notes", %{type: type} do
      note = %{"string" => "bar", "list" => "two"}

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
        |> Enum.map(&DataStructures.list_structure_notes/1)
        |> Enum.filter(&(Enum.count(&1) == 2))
        |> Enum.map(&Enum.at(&1, -1).df_content)

      assert Enum.count(df_contents) == structure_count
      Enum.each(df_contents, fn df_content -> assert df_content == note end)
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

    insert(:data_structure_type, name: type1, template_id: id_t1)
    insert(:data_structure_type, name: type2, template_id: id_t2)

    sts1 =
      Enum.map(1..5, fn id ->
        data_structure = insert(:data_structure, external_id: "ex_id#{id}")
        valid_structure_note(type1, data_structure, df_content: %{"text" => "foo"})
      end)

    sts2 =
      Enum.map(6..10, fn id ->
        data_structure = insert(:data_structure, external_id: "ex_id#{id}")
        valid_structure_note(type2, data_structure, [])
      end)

    [sts: sts1 ++ sts2]
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
end
