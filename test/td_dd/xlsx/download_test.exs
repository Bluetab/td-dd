defmodule TdDd.XLSX.DownloadTest do
  use TdDd.DataCase

  alias TdDd.XLSX.Download
  alias XlsxReader

  describe "TdDd.XLSX.Download.write_to_memory/3" do
    test "writes excel to memory for structures in editable download type" do
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
        domain_ids: [domain.id]
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
        domain_ids: [domain.id]
      }

      structure_url = "https://truedat.td.dd/structure/:id"

      assert {:ok, {file_name, blob}} =
               Download.write_to_memory([structure_type_1, structure_type_2], structure_url,
                 download_type: :editable
               )

      assert file_name == ~c"structures.xlsx"

      assert {:ok, workbook} = XlsxReader.open(blob, source: :binary)
      assert {:ok, [headers | content]} = XlsxReader.sheet(workbook, "type_1")

      assert Enum.count(headers) == 10

      assert Enum.take(headers, 8) == [
               "external_id",
               "name",
               "tech_name",
               "alias_name",
               "link_to_structure",
               "domain",
               "type",
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
                 "foo > bar",
                 "field_value",
                 ""
               ]
             ]

      assert {:ok, [headers | content]} = XlsxReader.sheet(workbook, "type_2")

      assert Enum.count(headers) == 9

      assert Enum.take(headers, 8) == [
               "external_id",
               "name",
               "tech_name",
               "alias_name",
               "link_to_structure",
               "domain",
               "type",
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
                 "bar > baz",
                 "field_value"
               ]
             ]
    end

    test "writes excel to memory for structures in non-editable download type" do
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
        inserted_at: "inserted_at_2",
        domain_ids: [domain.id]
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
  end
end
