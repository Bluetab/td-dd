defmodule TdDd.XLSX.ReaderTest do
  use TdDd.DataCase

  alias TdDd.Search.StructureEnricher
  alias TdDd.XLSX.Reader

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

  setup_all do
    start_supervised({Task.Supervisor, name: TdDd.TaskSupervisor})
    :ok
  end

  describe "TdDd.XLSX.Reader.parse/1" do
    setup do
      start_supervised!(StructureEnricher)

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

      domain = CacheHelpers.insert_domain()

      insert(:data_structure_type, name: type1, template_id: id_t1)
      insert(:data_structure_type, name: type2, template_id: id_t2)

      structures_type_1 =
        Enum.map(1..10, fn id ->
          data_structure =
            insert(:data_structure, external_id: "ex_id#{id}", domain_ids: [domain.id])

          valid_structure_note(type1, data_structure,
            df_content: %{"text" => %{"value" => "foo", "origin" => "user"}}
          )
        end)

      structures_type_2 =
        Enum.map(11..20, fn id ->
          data_structure = insert(:data_structure, external_id: "ex_id#{id}")
          opts = if Integer.mod(id, 2) !== 0, do: [], else: [status: :draft]
          valid_structure_note(type2, data_structure, opts)
        end)

      [structures: structures_type_1 ++ structures_type_2, hierarchy: hierarchy]
    end

    test "parses xlsx file", %{hierarchy: hierarchy} do
      assert parsed_rows = Reader.parse("test/fixtures/xlsx/upload.xlsx")

      assert {row_note, data_structure_info} =
               Enum.find(parsed_rows, fn {_content, %{data_structure: data_structure}} ->
                 data_structure.external_id == "ex_id1"
               end)

      assert data_structure_info.row_meta.index == 2

      assert row_note == %{
               "df_content" => %{
                 "critical" => %{"origin" => "file", "value" => "Yes"},
                 "text" => %{"origin" => "file", "value" => "text"},
                 "enriched_text" => %{"origin" => "file", "value" => %{}},
                 "urls_one_or_none" => %{
                   "origin" => "file",
                   "value" => [%{"url_name" => "", "url_value" => ""}]
                 }
               }
             }

      assert {row_note, data_structure_info} =
               Enum.find(parsed_rows, fn {_content, %{data_structure: data_structure}} ->
                 data_structure.external_id == "ex_id7"
               end)

      assert data_structure_info.row_meta.index == 6

      assert row_note == %{
               "df_content" => %{
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
                   "value" => [
                     %{
                       "url_name" => "",
                       "url_value" => "https://www.google.es"
                     }
                   ]
                 }
               }
             }

      assert {row_note, data_structure_info} =
               Enum.find(parsed_rows, fn {_content, %{data_structure: data_structure}} ->
                 data_structure.external_id == "ex_id11"
               end)

      assert data_structure_info.row_meta.index == 2

      assert row_note == %{
               "df_content" => %{
                 "hierarchy_name_1" => %{"origin" => "file", "value" => ""},
                 "hierarchy_name_2" => %{"origin" => "file", "value" => []},
                 "integer" => %{"origin" => "file", "value" => nil},
                 "key_value" => %{"origin" => "file", "value" => [""]},
                 "role" => %{"origin" => "file", "value" => ["Role", "Role 1"]}
               }
             }

      assert {row_note, data_structure_info} =
               Enum.find(parsed_rows, fn {_content, %{data_structure: data_structure}} ->
                 data_structure.external_id == "ex_id16"
               end)

      assert data_structure_info.row_meta.index == 7

      assert row_note == %{
               "df_content" => %{
                 "hierarchy_name_1" => %{"origin" => "file", "value" => ""},
                 "hierarchy_name_2" => %{"origin" => "file", "value" => []},
                 "integer" => %{"origin" => "file", "value" => 2},
                 "key_value" => %{"origin" => "file", "value" => [""]},
                 "role" => %{"origin" => "file", "value" => ["Miss This"]}
               }
             }

      assert {row_note, data_structure_info} =
               Enum.find(parsed_rows, fn {_content, %{data_structure: data_structure}} ->
                 data_structure.external_id == "ex_id18"
               end)

      assert data_structure_info.row_meta.index == 9

      assert row_note == %{
               "df_content" => %{
                 "hierarchy_name_1" => %{"origin" => "file", "value" => ""},
                 "hierarchy_name_2" => %{"origin" => "file", "value" => []},
                 "integer" => %{"origin" => "file", "value" => nil},
                 "key_value" => %{"origin" => "file", "value" => ["2"]},
                 "role" => %{"origin" => "file", "value" => ["Role 2"]}
               }
             }

      assert {row_note, data_structure_info} =
               Enum.find(parsed_rows, fn {_content, %{data_structure: data_structure}} ->
                 data_structure.external_id == "ex_id20"
               end)

      assert data_structure_info.row_meta.index == 11

      children_1 = Enum.find(hierarchy.nodes, fn %{name: name} -> name == "children_1" end)
      father = Enum.find(hierarchy.nodes, fn %{name: name} -> name == "father" end)

      assert row_note == %{
               "df_content" => %{
                 "hierarchy_name_1" => %{"origin" => "file", "value" => children_1.key},
                 "hierarchy_name_2" => %{
                   "origin" => "file",
                   "value" => [children_1.key, father.key]
                 },
                 "integer" => %{"origin" => "file", "value" => nil},
                 "key_value" => %{"origin" => "file", "value" => [""]},
                 "role" => %{"origin" => "file", "value" => []}
               }
             }
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
