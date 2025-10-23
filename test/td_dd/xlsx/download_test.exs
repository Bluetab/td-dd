defmodule TdDd.XLSX.DownloadTest do
  use TdDd.DataCase

  alias TdDd.XLSX.Download
  alias XlsxReader

  describe "TdDd.XLSX.Download.write_to_memory/3" do
    test "writes excel to memory for structures publised notes in editable download type" do
      domain = CacheHelpers.insert_domain()

      %{id: id} =
        CacheHelpers.insert_template(%{
          name: "template_1",
          scope: "dd",
          content: [
            %{
              "name" => "group",
              "fields" => [
                %{
                  "name" => "field_name",
                  "type" => "list",
                  "label" => "Label foo"
                },
                %{
                  "name" => "domain_inside_note_field",
                  "type" => "domain",
                  "label" => "domain_inside_note_field_label",
                  "cardinality" => "*"
                }
              ]
            }
          ]
        })

      insert(:data_structure_type, name: "type_1", template_id: id)

      structure_type_1 = %{
        name: "TechName_1",
        path: ["foo", "bar"],
        template: %{"name" => "template_1"},
        note: %{
          "field_name" => %{"value" => ["field_value"], "origin" => "user"},
          "domain_inside_note_field" => %{"value" => [], "origin" => "user"}
        },
        external_id: "ext_id",
        type: "type_1",
        data_structure_id: 0,
        domain_ids: [domain.id],
        system: %{"name" => "system_1"}
      }

      %{id: id} =
        CacheHelpers.insert_template(%{
          name: "template_2",
          scope: "dd",
          content: [
            %{
              "name" => "group",
              "fields" => [
                %{
                  "name" => "bar",
                  "type" => "list",
                  "label" => "Label bar"
                }
              ]
            }
          ]
        })

      insert(:data_structure_type, name: "type_2", template_id: id)

      structure_type_2 = %{
        name: "TechName_2",
        path: ["bar", "baz"],
        template: %{"name" => "template_2"},
        note: %{"bar" => %{"value" => ["field_value"], "origin" => "user"}},
        external_id: "ext_id_2",
        type: "type_2",
        data_structure_id: 1,
        domain_ids: [domain.id],
        system: %{"name" => "system_2"}
      }

      structure_url = "https://truedat.td.dd/structure/:id"

      assert {:ok, {file_name, blob}} =
               Download.write_to_memory([structure_type_1, structure_type_2], structure_url,
                 download_type: :editable,
                 note_type: :published
               )

      assert file_name == ~c"structures.xlsx"

      assert {:ok, workbook} = XlsxReader.open(blob, source: :binary)
      assert {:ok, [headers | content]} = XlsxReader.sheet(workbook, "type_1")

      assert Enum.count(headers) == 11

      assert Enum.take(headers, 9) == [
               "external_id",
               "name",
               "tech_name",
               "alias_name",
               "link_to_structure",
               "domain",
               "type",
               "system",
               "path"
             ]

      assert Enum.find(headers, &(&1 == "field_name"))
      assert Enum.find(headers, &(&1 == "domain_inside_note_field"))

      assert content == [
               [
                 "ext_id",
                 "TechName_1",
                 "TechName_1",
                 "",
                 "https://truedat.td.dd/structure/0",
                 domain.name,
                 "type_1",
                 "system_1",
                 "foo > bar",
                 "field_value",
                 ""
               ]
             ]

      assert {:ok, [headers | content]} = XlsxReader.sheet(workbook, "type_2")

      assert Enum.count(headers) == 10

      assert Enum.take(headers, 9) == [
               "external_id",
               "name",
               "tech_name",
               "alias_name",
               "link_to_structure",
               "domain",
               "type",
               "system",
               "path"
             ]

      assert Enum.find(headers, &(&1 == "bar"))

      assert content == [
               [
                 "ext_id_2",
                 "TechName_2",
                 "TechName_2",
                 "",
                 "https://truedat.td.dd/structure/1",
                 domain.name,
                 "type_2",
                 "system_2",
                 "bar > baz",
                 "field_value"
               ]
             ]
    end

    test "writes excel to memory for structures published notes in non-editable download type" do
      domain = CacheHelpers.insert_domain()

      %{id: id} =
        CacheHelpers.insert_template(%{
          name: "template_1",
          scope: "dd",
          content: [
            %{
              "name" => "group",
              "fields" => [
                %{
                  "name" => "field_name",
                  "type" => "list",
                  "label" => "Label foo"
                },
                %{
                  "name" => "domain_inside_note_field",
                  "type" => "domain",
                  "label" => "domain_inside_note_field_label",
                  "cardinality" => "*"
                }
              ]
            }
          ]
        })

      insert(:data_structure_type, name: "type_1", template_id: id)

      structure_type_1 = %{
        name: "TechName_1",
        path: ["foo", "bar"],
        template: %{"name" => "template_1"},
        note: %{
          "field_name" => %{"value" => ["field_value"], "origin" => "user"},
          "domain_inside_note_field" => %{
            "value" => [],
            "origin" => "user"
          }
        },
        external_id: "ext_id",
        type: "type_1",
        data_structure_id: 0,
        group: "group_1",
        system: %{"name" => "system_1"},
        domain: "domain_1",
        description: "description_1",
        inserted_at: "inserted_at_1",
        domain_ids: [domain.id],
        metadata: %{"alias" => "PostgreSQL"}
      }

      %{id: id} =
        CacheHelpers.insert_template(%{
          name: "template_2",
          scope: "dd",
          content: [
            %{
              "name" => "group",
              "fields" => [
                %{
                  "name" => "bar",
                  "type" => "list",
                  "label" => "Label bar"
                }
              ]
            }
          ]
        })

      insert(:data_structure_type, name: "type_2", template_id: id)

      structure_type_2 = %{
        name: "TechName_2",
        path: ["bar", "baz"],
        template: %{"name" => "template_2"},
        note: %{"bar" => %{"value" => ["field_value"], "origin" => "user"}},
        external_id: "ext_id_2",
        type: "type_2",
        data_structure_id: 1,
        group: "group_2",
        system: %{"name" => "system_2"},
        domain: "domain_2",
        description: "description_2",
        domain_ids: [domain.id],
        inserted_at: "inserted_at_2"
      }

      structure_url = "https://truedat.td.dd/structure/:id"

      assert {:ok, {file_name, blob}} =
               Download.write_to_memory([structure_type_1, structure_type_2], structure_url)

      assert file_name == ~c"structures.xlsx"

      assert {:ok, workbook} = XlsxReader.open(blob, source: :binary)
      assert {:ok, [headers | content]} = XlsxReader.sheet(workbook, "type_1")

      assert headers == [
               "type",
               "name",
               "tech_name",
               "alias_name",
               "link_to_structure",
               "group",
               "domain",
               "system",
               "path",
               "description",
               "external_id",
               "inserted_at",
               "metadata:alias"
             ]

      assert content == [
               [
                 "type_1",
                 "TechName_1",
                 "TechName_1",
                 "",
                 "https://truedat.td.dd/structure/0",
                 "group_1",
                 domain.name,
                 "system_1",
                 "foo > bar",
                 "description_1",
                 "ext_id",
                 "inserted_at_1",
                 "PostgreSQL"
               ]
             ]

      assert {:ok, [headers | content]} = XlsxReader.sheet(workbook, "type_2")

      assert headers == [
               "type",
               "name",
               "tech_name",
               "alias_name",
               "link_to_structure",
               "group",
               "domain",
               "system",
               "path",
               "description",
               "external_id",
               "inserted_at"
             ]

      assert content == [
               [
                 "type_2",
                 "TechName_2",
                 "TechName_2",
                 "",
                 "https://truedat.td.dd/structure/1",
                 "group_2",
                 domain.name,
                 "system_2",
                 "bar > baz",
                 "description_2",
                 "ext_id_2",
                 "inserted_at_2"
               ]
             ]
    end

    test "writes excel to memory for structures non_published notes in editable download type" do
      domain = CacheHelpers.insert_domain()

      %{id: id} =
        CacheHelpers.insert_template(%{
          name: "template_1",
          scope: "dd",
          content: [
            %{
              "name" => "group",
              "fields" => [
                %{
                  "name" => "field_name",
                  "type" => "list",
                  "label" => "Label foo"
                },
                %{
                  "name" => "domain_inside_note_field",
                  "type" => "domain",
                  "label" => "domain_inside_note_field_label",
                  "cardinality" => "*"
                }
              ]
            }
          ]
        })

      insert(:data_structure_type, name: "type_1", template_id: id)

      structure_type_1 = %{
        name: "TechName_1",
        path: ["foo", "bar"],
        template: %{"name" => "template_1"},
        non_published_note: %{
          "note" => %{
            "field_name" => %{"value" => ["field_value"], "origin" => "user"},
            "domain_inside_note_field" => %{
              "value" => [],
              "origin" => "user"
            }
          }
        },
        external_id: "ext_id",
        type: "type_1",
        data_structure_id: 0,
        domain_ids: [domain.id],
        system: %{"name" => "system_1"}
      }

      %{id: id} =
        CacheHelpers.insert_template(%{
          name: "template_2",
          scope: "dd",
          content: [
            %{
              "name" => "group",
              "fields" => [
                %{
                  "name" => "bar",
                  "type" => "list",
                  "label" => "Label bar"
                }
              ]
            }
          ]
        })

      insert(:data_structure_type, name: "type_2", template_id: id)

      structure_type_2 = %{
        name: "TechName_2",
        path: ["bar", "baz"],
        template: %{"name" => "template_2"},
        non_published_note: %{
          "note" => %{"bar" => %{"value" => ["field_value"], "origin" => "user"}}
        },
        external_id: "ext_id_2",
        type: "type_2",
        data_structure_id: 1,
        domain_ids: [domain.id],
        system: %{"name" => "system_2"}
      }

      structure_url = "https://truedat.td.dd/structure/:id"

      assert {:ok, {file_name, blob}} =
               Download.write_to_memory([structure_type_1, structure_type_2], structure_url,
                 download_type: :editable,
                 note_type: :non_published
               )

      assert file_name == ~c"structures.xlsx"

      assert {:ok, workbook} = XlsxReader.open(blob, source: :binary)
      assert {:ok, [headers | content]} = XlsxReader.sheet(workbook, "type_1")

      assert Enum.count(headers) == 11

      assert Enum.take(headers, 9) == [
               "external_id",
               "name",
               "tech_name",
               "alias_name",
               "link_to_structure",
               "domain",
               "type",
               "system",
               "path"
             ]

      assert Enum.find(headers, &(&1 == "field_name"))
      assert Enum.find(headers, &(&1 == "domain_inside_note_field"))

      assert content == [
               [
                 "ext_id",
                 "TechName_1",
                 "TechName_1",
                 "",
                 "https://truedat.td.dd/structure/0",
                 domain.name,
                 "type_1",
                 "system_1",
                 "foo > bar",
                 "field_value",
                 ""
               ]
             ]

      assert {:ok, [headers | content]} = XlsxReader.sheet(workbook, "type_2")

      assert Enum.count(headers) == 10

      assert Enum.take(headers, 9) == [
               "external_id",
               "name",
               "tech_name",
               "alias_name",
               "link_to_structure",
               "domain",
               "type",
               "system",
               "path"
             ]

      assert Enum.find(headers, &(&1 == "bar"))

      assert content == [
               [
                 "ext_id_2",
                 "TechName_2",
                 "TechName_2",
                 "",
                 "https://truedat.td.dd/structure/1",
                 domain.name,
                 "type_2",
                 "system_2",
                 "bar > baz",
                 "field_value"
               ]
             ]
    end
  end

  describe "TdDd.XLSX.write_to_memory_grants/3" do
    test "writes excel to memory for grants" do
      CacheHelpers.insert_domain(id: 3, name: "Demo Truedat")

      grant_1 = %{
        data_structure_version: %{
          class: "field",
          classes: nil,
          confidential: false,
          data_structure_id: 4_160_488,
          deleted_at: nil,
          description: "Embalaje de tipo bulto único por EM (optimiz.área carga)",
          domain_ids: [3],
          external_id: "Clientes/KNA1//VSO/R_ONE_SORT",
          field_type: "CHAR",
          group: "Clientes",
          id: 4_160_488,
          inserted_at: "2019-04-16T16:12:48.000000Z",
          latest_note: nil,
          linked_concepts: false,
          metadata: %{nullable: false, precision: "1,0", type: "CHAR", alias: "metadata_alias"},
          mutable_metadata: nil,
          name: "/VSO/R_ONE_SORT",
          path: ["KNA1", "id"],
          source_alias: nil,
          source_id: 132,
          system: %{external_id: "sap", id: 1, name: "SAP"},
          system_id: 1,
          tags: nil,
          type: "Column",
          updated_at: "2019-04-16T16:13:55.000000Z",
          version: 0,
          with_content: false,
          with_profiling: false
        },
        detail: %{access_level: "Low", granted_by: "Admin"},
        end_date: "2023-05-16",
        id: 6,
        start_date: "2020-05-17",
        user: %{full_name: "Euclydes Netto"},
        user_id: 23
      }

      grants = [grant_1]

      assert {:ok, {file_name, blob}} =
               Download.write_to_memory_grants(grants)

      assert file_name == ~c"grants.xlsx"

      assert {:ok, workbook} = XlsxReader.open(blob, source: :binary)
      assert {:ok, [xlsx_headers | xlsx_content]} = XlsxReader.sheet(workbook, "Grants")

      assert xlsx_headers == [
               "user_name",
               "data_structure_name",
               "domain_name",
               "system_name",
               "structure_path",
               "start_date",
               "end_date",
               "grant_details"
             ]

      assert xlsx_content == [
               [
                 "Euclydes Netto",
                 "/VSO/R_ONE_SORT",
                 "Demo Truedat",
                 "SAP",
                 "KNA1 > id",
                 "2020-05-17",
                 "2023-05-16",
                 "{\"access_level\":\"Low\",\"granted_by\":\"Admin\"}"
               ]
             ]
    end
  end
end
