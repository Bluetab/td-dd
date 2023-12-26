defmodule TdDd.CSV.DownloadTest do
  @moduledoc """
  Tests download of structures in csv format
  """
  use TdDd.DataCase

  alias TdDd.CSV.Download

  describe "Structures download" do
    test "download empty csv" do
      csv = Download.to_csv([])
      assert csv == ""
    end

    test "to_csv/1 return csv content to download" do
      template_name = "Table"
      field_name = "add_info1"
      field_label = "Add Info 1"
      template_id = 1
      type = "Columna"

      CacheHelpers.insert_template(%{
        id: template_id,
        name: template_name,
        label: "label",
        scope: "dd",
        content: [
          %{
            "name" => "group",
            "fields" => [
              %{
                "name" => field_name,
                "type" => "list",
                "label" => field_label
              }
            ]
          }
        ]
      })

      insert(:data_structure_type, name: type, template_id: template_id)
      domain_name = "domain_1"

      structure_1 = %{
        name: "1. 4. 4 Primas Bajas (grafico)",
        description: "Gráfico de evolución mensual de la prima",
        template: %{"name" => template_name},
        note: %{field_name => ["field_value"]},
        domain: %{"external_id" => "ex_id_1", "name" => domain_name},
        inserted_at: "2018-05-05",
        external_id: "myext_292929",
        group: "gr",
        path: ["CMC", "Objetos Públicos", "Informes", "Cuadro de Mando Integral"],
        type: type,
        system: %{"external_id" => "sys", "name" => "sys_name"}
      }

      structures = [structure_1]
      csv = Download.to_csv(structures)

      assert csv ==
               """
               type;name;group;domain;system;path;description;external_id;inserted_at;Add Info 1\r
               #{structure_1.type};#{structure_1.name};#{structure_1.group};#{domain_name};#{Map.get(structure_1.system, "name")};CMC > Objetos Públicos > Informes > Cuadro de Mando Integral;#{structure_1.description};#{structure_1.external_id};#{structure_1.inserted_at};field_value\r
               """
    end

    test "to_editable_csv/1 return csv content to download" do
      CacheHelpers.insert_template(%{
        id: 42,
        name: "template",
        label: "label",
        scope: "dd",
        content: [
          %{
            "name" => "group",
            "fields" => [
              %{
                "name" => "field_name",
                "type" => "list",
                "label" => "Label foo"
              }
            ]
          }
        ]
      })

      insert(:data_structure_type, name: "type", template_id: 42)

      structures = [
        %{
          name: "name",
          path: ["foo", "bar"],
          template: %{"name" => "template"},
          note: %{"field_name" => ["field_value"]},
          external_id: "ext_id",
          type: "type"
        }
      ]

      assert Download.to_editable_csv(structures) ==
               """
               external_id;name;type;path;field_name\r
               ext_id;name;type;foo > bar;field_value\r
               """
    end
  end

  describe "Structure downloads with multiple fields" do
    test "to_editable_csv/1 return csv content with multiple fields, to download" do
      CacheHelpers.insert_template(%{
        id: 42,
        name: "template",
        label: "label",
        scope: "dd",
        content: [
          %{
            "name" => "group",
            "fields" => [
              %{
                "name" => "field_numbers",
                "type" => "integer",
                "label" => "Label foo",
                "cardinality" => "*"
              },
              %{
                "name" => "field_texts",
                "type" => "string",
                "label" => "Label foo",
                "cardinality" => "+"
              },
              %{
                "name" => "field_text",
                "type" => "string",
                "label" => "Label foo",
                "cardinality" => "1"
              },
              %{
                "name" => "field_domains",
                "type" => "domain",
                "label" => "Label foo",
                "cardinality" => "*"
              }
            ]
          }
        ]
      })

      insert(:data_structure_type, name: "type", template_id: 42)

      structures = [
        %{
          name: "name",
          path: ["foo", "bar"],
          template: %{"name" => "template"},
          note: %{
            "field_numbers" => [1, 2],
            "field_texts" => ["multi", "field"],
            "field_text" => ["field"],
            "field_domains" => [%{"name" => "domain_1"}, %{"name" => "domain_2"}]
          },
          external_id: "ext_id",
          type: "type"
        }
      ]

      assert Download.to_editable_csv(structures) ==
               """
               external_id;name;type;path;field_numbers;field_texts;field_text;field_domains\r
               ext_id;name;type;foo > bar;1|2;multi|field;field;domain_1, domain_2\r
               """
    end

    test "to_csv/1 return csv content with multiple fields to download" do
      template_name = "Table"
      field_label = "Label foo"
      template_id = 1
      type = "Columna"

      CacheHelpers.insert_template(%{
        id: template_id,
        name: template_name,
        label: "label",
        scope: "dd",
        content: [
          %{
            "name" => "group",
            "fields" => [
              %{
                "name" => "field_numbers",
                "type" => "integer",
                "label" => field_label <> "1",
                "cardinality" => "*"
              },
              %{
                "name" => "field_texts",
                "type" => "string",
                "label" => field_label <> "2",
                "cardinality" => "+"
              },
              %{
                "name" => "field_text",
                "type" => "string",
                "label" => field_label <> "3",
                "cardinality" => "1"
              }
            ]
          }
        ]
      })

      insert(:data_structure_type, name: type, template_id: template_id)
      domain_name = "domain_1"

      structure_1 = %{
        name: "1. 4. 4 Primas Bajas (grafico)",
        description: "Gráfico de evolución mensual de la prima",
        template: %{"name" => template_name},
        note: %{
          "field_numbers" => [1, 2],
          "field_texts" => ["multi", "field"],
          "field_text" => ["field"]
        },
        domain: %{"external_id" => "ex_id_1", "name" => domain_name},
        inserted_at: "2018-05-05",
        external_id: "myext_292929",
        group: "gr",
        path: ["CMC", "Objetos Públicos", "Informes", "Cuadro de Mando Integral"],
        type: type,
        system: %{"external_id" => "sys", "name" => "sys_name"}
      }

      assert Download.to_csv([structure_1]) ==
               """
               type;name;group;domain;system;path;description;external_id;inserted_at;#{field_label}1;#{field_label}2;#{field_label}3\r
               #{structure_1.type};#{structure_1.name};#{structure_1.group};#{domain_name};#{Map.get(structure_1.system, "name")};CMC > Objetos Públicos > Informes > Cuadro de Mando Integral;#{structure_1.description};#{structure_1.external_id};#{structure_1.inserted_at};1|2;multi|field;field\r
               """
    end
  end

  describe "Lineage download" do
    test "linage_to_csv/3 return csv content" do
      contains_row = [
        source: %{external_id: "eid1", name: "name", class: "Group"},
        target: %{external_id: "eid2", name: "name1", class: "Group"}
      ]

      contains = [contains_row]

      depends_row = [
        source: %{external_id: "eid3", name: "name2", class: "Resource"},
        target: %{external_id: "eid4", name: "name3", class: "Resource"}
      ]

      depends = [depends_row]

      headers = %{
        "source_external_id" => "Id Origen",
        "source_name" => "Nombre Origen",
        "source_class" => "Tipo Origen",
        "target_external_id" => "Id Destino",
        "target_name" => "Nombre Destino",
        "target_class" => "Tipo Destino",
        "relation_type" => "Tipo Relación"
      }

      assert Download.linage_to_csv(contains, depends, headers) ==
               """
               Id Origen;Nombre Origen;Tipo Origen;Id Destino;Nombre Destino;Tipo Destino;Tipo Relación\r
               #{contains_row[:source].external_id};#{contains_row[:source].name};Group;#{contains_row[:target].external_id};#{contains_row[:target].name};Group;CONTAINS\r
               #{depends_row[:source].external_id};#{depends_row[:source].name};Resource;#{depends_row[:target].external_id};#{depends_row[:target].name};Resource;DEPENDS\r
               """
    end
  end

  describe "Grant download" do
    test "to_csv_grant/3 return csv content" do
      grant_1 = %{
        data_structure_version: %{
          class: "field",
          classes: nil,
          confidential: false,
          data_structure_id: 4_160_488,
          deleted_at: nil,
          description: "Embalaje de tipo bulto único por EM (optimiz.área carga)",
          domain: %{external_id: "Demo Truedat", id: 3, name: "Demo Truedat"},
          domain_id: 3,
          domain_ids: [3],
          external_id: "Clientes/KNA1//VSO/R_ONE_SORT",
          field_type: "CHAR",
          group: "Clientes",
          id: 4_160_488,
          inserted_at: "2019-04-16T16:12:48.000000Z",
          latest_note: nil,
          linked_concepts: false,
          metadata: %{nullable: false, precision: "1,0", type: "CHAR"},
          mutable_metadata: nil,
          name: "/VSO/R_ONE_SORT",
          path: ["KNA1"],
          path_sort: "KNA1",
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
        detail: %{},
        end_date: "2023-05-16",
        id: 6,
        start_date: "2020-05-17",
        user: %{full_name: "Euclydes Netto"},
        user_id: 23
      }

      grants = [grant_1]

      header_labels = %{
        "user_name" => "User",
        "data_structure_name" => "Structure",
        "start_date" => "Start date",
        "end_date" => "End date",
        "metadata" => "Metadata",
        "mutable_metadata" => "Mutable metadata"
      }

      assert Download.to_csv_grants(grants, header_labels) ==
               """
               User;Structure;Start date;End date;Metadata;Mutable metadata\r
               #{grant_1.user.full_name};#{grant_1.data_structure_version.name};#{grant_1.start_date};#{grant_1.end_date};\"{\"\"nullable\"\":false,\"\"precision\"\":\"\"1,0\"\",\"\"type\"\":\"\"CHAR\"\"}\";null\r
               """
    end
  end
end
