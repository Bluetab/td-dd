defmodule TdDd.DataStructures.BulkUpdateTest do
  use TdDd.DataCase

  import TdDd.TestOperators

  alias TdCache.StructureTypeCache
  alias TdCache.TemplateCache
  alias TdDd.DataStructures
  alias TdDd.DataStructures.BulkUpdate
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Repo

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

  setup_all do
    %{id: template_id, name: template_name} = template = build(:template)
    TemplateCache.put(template, publish: false)

    on_exit(fn -> TemplateCache.delete(template_id) end)

    [template: template, type: template_name]
  end

  setup %{template: %{id: template_id}, type: type} do
    CacheHelpers.insert_structure_type(structure_type: type, template_id: template_id)

    start_supervised!(TdDd.Search.StructureEnricher)
    :ok
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

  describe "update_all/3" do
    test "update all data structures with valid data", %{type: type} do
      claims = build(:claims)

      ids =
        1..10
        |> Enum.map(fn _ -> valid_structure(type, df_content: %{"string" => "foo"}) end)
        |> Enum.map(& &1.data_structure_id)

      assert {:ok, %{updates: updates}} = BulkUpdate.update_all(ids, @valid_params, claims)
      assert Map.keys(updates) <|> ids

      assert ids
             |> Enum.map(&Repo.get(DataStructure, &1))
             |> Enum.map(& &1.df_content)
             |> Enum.all?(&(&1 == @valid_content))
    end

    test "emits audit events for updated structures", %{type: type} do
      claims = build(:claims)

      ids =
        1..10
        |> Enum.map(fn _ -> valid_structure(type) end)
        |> Enum.map(& &1.data_structure_id)

      assert {:ok, %{updates: updates, audit: audit}} =
               BulkUpdate.update_all(ids, @valid_params, claims)

      assert Enum.count(audit) == Enum.count(updates)
    end

    test "ignores unchanged data structures", %{type: type} do
      %{user_id: user_id} = claims = build(:claims)

      ids =
        1..10
        |> Enum.map(fn
          n when n > 5 -> valid_structure(type, df_content: @valid_content, last_change_by: 99)
          _ -> valid_structure(type, df_content: %{"string" => "foo", "list" => "bar"})
        end)
        |> Enum.map(& &1.data_structure_id)

      assert {:ok, %{updates: updates}} = BulkUpdate.update_all(ids, @valid_params, claims)

      structures = Enum.map(ids, &Repo.get(DataStructure, &1))

      assert structures
             |> Enum.map(& &1.df_content)
             |> Enum.all?(&(&1 == @valid_content))

      assert %{99 => unchanged_ids, ^user_id => changed_ids} =
               Enum.group_by(structures, & &1.last_change_by, & &1.id)

      assert Enum.count(unchanged_ids) == 5
      assert Enum.count(changed_ids) == 5
      assert Map.keys(updates) <|> changed_ids
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
               BulkUpdate.update_all(ids, @valid_params, claims)

      assert {%{errors: errors}, data_structure} = changeset
      assert %{external_id: "the bad one"} = data_structure
      assert {"invalid template", _} = errors[:df_content]
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
               BulkUpdate.update_all(ids, %{"df_content" => %{"string" => "updated"}}, claims)

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

      # assert ids
      #        |> Enum.map(&Repo.get(DataStructure, &1))
      #        |> Enum.map(& &1.df_content)
      #        |> Enum.all?(&(&1 == %{"string" => "updated", "list" => initial_content["list"]}))
    end

    test "only validates specified fields", %{type: type} do
      claims = build(:claims)

      id = valid_structure_note(type, df_content: %{"list" => "two"}).data_structure_id

      assert {:ok, %{update_notes: _update_notes}} =
               BulkUpdate.update_all([id], %{"df_content" => %{"list" => "one"}}, claims)

      %{df_content: df_content} =
        id
        |> DataStructures.list_structure_notes()
        |> Enum.at(-1)

      # TODO Check with Juan
      assert %{"list" => "one"} = df_content
      # assert df_content == %{"list" => "one"}
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
                 claims
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
    setup [:from_csv_templates]

    test "update all data structures content", %{sts: sts} do
      claims = build(:claims)
      structure_ids = Enum.map(sts, & &1.data_structure_id)
      upload = %{path: "test/fixtures/td2942/upload.csv"}
      assert {:ok, %{updates: updates}} = BulkUpdate.from_csv(upload, claims)
      ids = Map.keys(updates)
      assert length(ids) == 9
      assert Enum.all?(ids, fn id -> id in structure_ids end)

      assert %{"text" => "text", "critical" => "Yes", "role" => ["Role"], "key_value" => ["1"]} =
               DataStructures.get_data_structure_by_external_id("ex_id1").df_content

      assert %{"text" => "text2", "critical" => "Yes", "role" => ["Role"]} =
               DataStructures.get_data_structure_by_external_id("ex_id2").df_content

      assert %{"text" => "foo", "critical" => "No", "role" => ["Role"]} =
               DataStructures.get_data_structure_by_external_id("ex_id3").df_content

      assert %{"text" => "foo", "critical" => "No", "role" => ["Role 1"]} =
               DataStructures.get_data_structure_by_external_id("ex_id4").df_content

      assert %{"text" => "foo", "critical" => "No", "role" => ["Role 2"], "key_value" => ["2"]} =
               DataStructures.get_data_structure_by_external_id("ex_id5").df_content

      text = to_enriched_text("I’m 6")

      assert %{"enriched_text" => ^text} =
               DataStructures.get_data_structure_by_external_id("ex_id6").df_content

      text = to_enriched_text("Enriched text")
      url = to_content_url("https://www.google.es")

      assert %{"enriched_text" => ^text, "urls_one_or_none" => ^url, "integer" => 3} =
               DataStructures.get_data_structure_by_external_id("ex_id7").df_content

      assert %{"urls_one_or_none" => ^url, "integer" => 2} =
               DataStructures.get_data_structure_by_external_id("ex_id8").df_content

      text = to_enriched_text("I’m 9")

      assert %{"enriched_text" => ^text, "integer" => 9} =
               DataStructures.get_data_structure_by_external_id("ex_id9").df_content

      assert %{} = DataStructures.get_data_structure_by_external_id("ex_id9").df_content
    end

    test "returns error on content" do
      claims = build(:claims)
      upload = %{path: "test/fixtures/td2942/upload_invalid.csv"}

      assert {:error, :updates, %{errors: [df_content: {_, [critical: {_, validation}]}]}, _} =
               BulkUpdate.from_csv(upload, claims)

      assert Keyword.get(validation, :validation) == :inclusion
      assert Keyword.get(validation, :enum) == ["Yes", "No"]

      assert %{"text" => "foo"} =
               DataStructures.get_data_structure_by_external_id("ex_id1").df_content
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

      BulkUpdate.update_all(data_structure_ids, %{"df_content" => note}, build(:claims))

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

      BulkUpdate.update_all(data_structure_ids, %{"df_content" => note}, build(:claims))

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

      BulkUpdate.update_all(data_structure_ids, %{"df_content" => note}, build(:claims))

      df_contents =
        data_structure_ids
        |> Enum.map(&DataStructures.list_structure_notes/1)
        |> Enum.filter(&(Enum.count(&1) == 2))
        |> Enum.map(&Enum.at(&1, -1).df_content)

      assert Enum.count(df_contents) == structure_count
      Enum.each(df_contents, fn df_content -> assert df_content == note end)
    end

    test "bulk upload notes of data structures with pending_approval notes", %{type: type} do
      note = %{"string" => "bar", "list" => "two"}

      structure_count = 5

      data_structure_ids =
        1..structure_count
        |> Enum.map(fn _ -> valid_structure(type) end)
        |> Enum.map(
          &insert(:structure_note, status: :pending_approval, data_structure: &1.data_structure)
        )
        |> Enum.map(& &1.data_structure_id)

      result = BulkUpdate.update_all(data_structure_ids, %{"df_content" => note}, build(:claims))
      assert {:error, :update_notes, {:only_draft_are_editable, %DataStructure{}}, %{}} = result

      df_contents =
        data_structure_ids
        |> Enum.map(&DataStructures.list_structure_notes/1)
        |> Enum.filter(&(Enum.count(&1) == 1))
        |> Enum.map(&Enum.at(&1, -1).df_content)

      assert Enum.count(df_contents) == structure_count
      Enum.each(df_contents, fn df_content -> assert df_content == %{} end)
    end
  end

  defp invalid_structure do
    insert(:data_structure_version,
      type: "missing_type",
      data_structure:
        build(:data_structure, external_id: "the bad one", df_content: %{"foo" => "bar"})
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

    insert(:data_structure_version,
      type: type,
      data_structure: data_structure
    )

    insert(:structure_note, [data_structure: data_structure] ++ sn_opts)
  end

  defp from_csv_templates(_) do
    %{id: id_t1, name: type} = t1 = build(:template, content: @c1)
    TemplateCache.put(t1, publish: false)
    %{id: st1_id} = st1 = insert(:data_structure_type, structure_type: type, template_id: id_t1)
    {:ok, _} = StructureTypeCache.put(st1)

    sts1 =
      Enum.map(1..5, fn id ->
        valid_structure(type, external_id: "ex_id#{id}", df_content: %{"text" => "foo"})
      end)

    %{id: id_t2, name: type} = t2 = build(:template, content: @c2)
    TemplateCache.put(t2, publish: false)
    %{id: st2_id} = st2 = insert(:data_structure_type, structure_type: type, template_id: id_t2)
    {:ok, _} = StructureTypeCache.put(st2)
    sts2 = Enum.map(6..10, fn id -> valid_structure(type, external_id: "ex_id#{id}") end)

    on_exit(fn ->
      TemplateCache.delete(id_t1)
      TemplateCache.delete(id_t2)

      StructureTypeCache.delete(st1_id)
      StructureTypeCache.delete(st2_id)
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
