defmodule TdDd.CSV.DownloadTest do
  @moduledoc """
  Tests download of structures in csv format
  """
  use TdDd.DataCase

  alias TdDd.CSV.Download

  @lang "es"

  describe "Structures download" do
    test "download empty csv" do
      csv = Download.to_csv([], nil, nil, "es")
      assert csv == ""
    end

    test "to_csv/4 return csv content to download" do
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
        note: %{field_name => %{"value" => ["field_value"], "origin" => "user"}},
        domain: %{"external_id" => "ex_id_1", "name" => domain_name},
        inserted_at: "2018-05-05",
        external_id: "myext_292929",
        group: "gr",
        path: ["CMC", "Objetos Públicos", "Informes", "Cuadro de Mando Integral"],
        type: type,
        system: %{"external_id" => "sys", "name" => "sys_name"}
      }

      structures = [structure_1]

      csv = Download.to_csv(structures, nil, nil, @lang)

      assert csv ==
               """
               type;name;group;domain;system;path;description;external_id;inserted_at;Add Info 1\r
               #{structure_1.type};#{structure_1.name};#{structure_1.group};#{domain_name};#{Map.get(structure_1.system, "name")};CMC > Objetos Públicos > Informes > Cuadro de Mando Integral;#{structure_1.description};#{structure_1.external_id};#{structure_1.inserted_at};field_value\r
               """
    end

    test "to_csv/4 return csv content to download with tech_name, alias_name and structure link" do
      field_name = "add_info1"
      field_label = "Add Info 1"
      type = "Columna"

      %{id: template_id, name: template_name} =
        CacheHelpers.insert_template(%{
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
      %{name: domain_name} = CacheHelpers.insert_domain()

      # Structure without Alias
      structure_1 = %{
        name: "TechName_1",
        description: "Loren impusm",
        template: %{"name" => template_name},
        note: %{field_name => %{"value" => ["field_value"], "origin" => "user"}},
        domain: %{"external_id" => "ex_id_1", "name" => domain_name},
        inserted_at: "2023-05-15",
        external_id: "myext_123456",
        group: "gr",
        path: ["LOREM", "Ipsum Dolor", "Amet"],
        type: type,
        system: %{"external_id" => "sys", "name" => "sys_name"},
        data_structure_id: 8
      }

      # Structure with Alias
      structure_2 = %{
        name: "Alias Name 2",
        original_name: "TechName_2",
        alias: "Alias Name 2",
        description: "Lorem Ipsum",
        template: %{"name" => template_name},
        note: %{
          field_name => %{"value" => ["field_value"], "origin" => "user"},
          "alias" => %{"value" => "Alias Name 2", "origin" => "user"}
        },
        domain: %{"external_id" => "ex_id_2", "name" => domain_name},
        inserted_at: "2023-05-15",
        external_id: "myext_234567",
        group: "gr",
        path: ["LOREM", "Ipsum Dolor", "Sit"],
        type: type,
        system: %{"external_id" => "sys", "name" => "sys_name"},
        data_structure_id: 9
      }

      # Simulating structure_url_schema input from web and conversion for structures
      structure_url_schema = "https://truedat.td.dd/structure/:id"

      structure_1_url_schema_converted =
        "https://truedat.td.dd/structure/" <> to_string(structure_1.data_structure_id)

      structure_2_url_schema_converted =
        "https://truedat.td.dd/structure/" <> to_string(structure_2.data_structure_id)

      structures = [structure_1, structure_2]
      csv = Download.to_csv(structures, nil, structure_url_schema, @lang)

      assert csv ==
               """
               type;tech_name;alias_name;link_to_structure;group;domain;system;path;description;external_id;inserted_at;Add Info 1\r
               #{structure_1.type};#{structure_1.name};;#{structure_1_url_schema_converted};#{structure_1.group};#{domain_name};#{Map.get(structure_1.system, "name")};#{Enum.join(structure_1.path, " > ")};#{structure_1.description};#{structure_1.external_id};#{structure_1.inserted_at};field_value\r
               #{structure_2.type};#{structure_2.original_name};#{structure_2.alias};#{structure_2_url_schema_converted};#{structure_2.group};#{domain_name};#{Map.get(structure_2.system, "name")};#{Enum.join(structure_2.path, " > ")};#{structure_2.description};#{structure_2.external_id};#{structure_2.inserted_at};field_value\r
               """
    end

    test "to_csv/4 return csv content to download with hierarchy" do
      template_name = "column"
      field_name = "hierarchy_field"
      field_label = "Hierarchy Field"
      template_id = 1
      type = "Column"

      CacheHelpers.insert_hierarchy(
        id: 1927,
        nodes: [
          build(:hierarchy_node, %{
            node_id: 50,
            name: "node_0",
            parent_id: nil,
            hierarchy_id: 1927,
            path: "/node_0"
          }),
          build(:hierarchy_node, %{
            node_id: 51,
            name: "node_1",
            parent_id: nil,
            hierarchy_id: 1927,
            path: "/node_1"
          })
        ]
      )

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
                "type" => "hierarchy",
                "name" => field_name,
                "label" => field_label,
                "values" => %{"hierarchy" => %{"id" => 1927}},
                "cardinality" => "*"
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
        note: %{field_name => %{"value" => ["1927_50", "1927_51"], "origin" => "user"}},
        domain: %{"external_id" => "ex_id_1", "name" => domain_name},
        inserted_at: "2018-05-05",
        external_id: "myext_292929",
        group: "gr",
        path: ["CMC", "Objetos Públicos", "Informes", "Cuadro de Mando Integral"],
        type: type,
        system: %{"external_id" => "sys", "name" => "sys_name"}
      }

      structures = [structure_1]
      csv = Download.to_csv(structures, nil, nil, "")

      expected_hierarchy_value = "/node_0|/node_1"

      assert csv ==
               """
               type;name;group;domain;system;path;description;external_id;inserted_at;#{field_label}\r
               #{structure_1.type};#{structure_1.name};#{structure_1.group};#{domain_name};#{Map.get(structure_1.system, "name")};CMC > Objetos Públicos > Informes > Cuadro de Mando Integral;#{structure_1.description};#{structure_1.external_id};#{structure_1.inserted_at};#{expected_hierarchy_value}\r
               """
    end

    test "to_csv/4 return csv content to download with domain paths, also note domains by their name" do
      template_name = "Table"
      field_name = "add_info1"
      field_label = "Add Info 1"
      template_id = 1
      type = "Column"

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

      insert(:data_structure_type, name: type, template_id: template_id)

      %{id: domain_id, name: domain_name} = CacheHelpers.insert_domain(%{name: "domain_1"})

      %{id: domain_inside_note_1_id} =
        CacheHelpers.insert_domain(%{
          name: "domain_inside_note_1_name",
          external_id: "domain_inside_note_1_external_id"
        })

      %{id: domain_inside_note_2_id} =
        CacheHelpers.insert_domain(%{
          name: "domain_inside_note_2_name",
          external_id: "domain_inside_note_2_external_id"
        })

      %{id: subdomain_id, name: subdomain_name} =
        CacheHelpers.insert_domain(%{name: "subdomain_1", parent_id: domain_id})

      structure_1 = %{
        name: "1. 4. 4 Primas Bajas (grafico)",
        description: "Gráfico de evolución mensual de la prima",
        template: %{"name" => template_name},
        note: %{
          field_name => %{"value" => ["field_value"], "origin" => "user"},
          "domain_inside_note_field" => %{
            "value" => [domain_inside_note_1_id, domain_inside_note_2_id],
            "origin" => "user"
          }
        },
        domain_ids: [domain_id, subdomain_id],
        domain: %{"external_id" => "ex_id_1", "name" => domain_name},
        inserted_at: "2018-05-05",
        external_id: "myext_292929",
        group: "gr",
        path: ["CMC", "Objetos Públicos", "Informes", "Cuadro de Mando Integral"],
        type: type,
        system: %{"external_id" => "sys", "name" => "sys_name"}
      }

      structures = [structure_1]
      csv = Download.to_csv(structures, nil, nil, "")

      assert csv ==
               """
               type;name;group;domain;system;path;description;external_id;inserted_at;Add Info 1;domain_inside_note_field_label\r
               #{structure_1.type};#{structure_1.name};#{structure_1.group};#{domain_name}|#{domain_name}/#{subdomain_name};#{Map.get(structure_1.system, "name")};CMC > Objetos Públicos > Informes > Cuadro de Mando Integral;#{structure_1.description};#{structure_1.external_id};#{structure_1.inserted_at};field_value;domain_inside_note_1_name|domain_inside_note_2_name\r
               """
    end

    test "to_csv/4 return csv content with multiple fields to download" do
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
          "field_numbers" => %{"value" => [1, 2], "origin" => "user"},
          "field_texts" => %{"value" => ["multi", "field"], "origin" => "user"},
          "field_text" => %{"value" => ["field"], "origin" => "user"}
        },
        domain: %{"external_id" => "ex_id_1", "name" => domain_name},
        inserted_at: "2018-05-05",
        external_id: "myext_292929",
        group: "gr",
        path: ["CMC", "Objetos Públicos", "Informes", "Cuadro de Mando Integral"],
        type: type,
        system: %{"external_id" => "sys", "name" => "sys_name"}
      }

      assert Download.to_csv([structure_1], nil, nil, "") ==
               """
               type;name;group;domain;system;path;description;external_id;inserted_at;#{field_label}1;#{field_label}2;#{field_label}3\r
               #{structure_1.type};#{structure_1.name};#{structure_1.group};#{domain_name};#{Map.get(structure_1.system, "name")};CMC > Objetos Públicos > Informes > Cuadro de Mando Integral;#{structure_1.description};#{structure_1.external_id};#{structure_1.inserted_at};1|2;multi|field;field\r
               """
    end

    test "to_csv/4 return csv translate" do
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

      column_es_1 = "column es 11"
      column_es_2 = "column es 22"

      CacheHelpers.put_i18n_messages("es", [
        %{message_id: "fields.#{field_label}1", definition: column_es_1},
        %{message_id: "fields.#{field_label}2", definition: column_es_2}
      ])

      insert(:data_structure_type, name: type, template_id: template_id)
      domain_name = "domain_1"

      structure_1 = %{
        name: "1. 4. 4 Primas Bajas (grafico)",
        description: "Gráfico de evolución mensual de la prima",
        template: %{"name" => template_name},
        note: %{
          "field_numbers" => %{"value" => [1, 2], "origin" => "user"},
          "field_texts" => %{"value" => ["multi", "field"], "origin" => "user"},
          "field_text" => %{"value" => ["field"], "origin" => "user"}
        },
        domain: %{"external_id" => "ex_id_1", "name" => domain_name},
        inserted_at: "2018-05-05",
        external_id: "myext_292929",
        group: "gr",
        path: ["CMC", "Objetos Públicos", "Informes", "Cuadro de Mando Integral"],
        type: type,
        system: %{"external_id" => "sys", "name" => "sys_name"}
      }

      assert Download.to_csv([structure_1], nil, nil, "es") ==
               """
               type;name;group;domain;system;path;description;external_id;inserted_at;#{column_es_1};#{column_es_2};#{field_label}3\r
               #{structure_1.type};#{structure_1.name};#{structure_1.group};#{domain_name};#{Map.get(structure_1.system, "name")};CMC > Objetos Públicos > Informes > Cuadro de Mando Integral;#{structure_1.description};#{structure_1.external_id};#{structure_1.inserted_at};1|2;multi|field;field\r
               """
    end

    test "to_editable_csv return csv content to download" do
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
          note: %{"field_name" => %{"value" => ["field_value"], "origin" => "user"}},
          external_id: "ext_id",
          type: "type"
        }
      ]

      assert Download.to_editable_csv(structures, nil, @lang) ==
               """
               external_id;name;type;path;field_name\r
               ext_id;name;type;foo > bar;field_value\r
               """
    end

    test "to_editable_csv return csv content to download with tech_name, alias_name and structure link" do
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

      %{id: domain_inside_note_1_id} =
        CacheHelpers.insert_domain(%{
          name: "domain_inside_note_1_name",
          external_id: "domain_inside_note_1_external_id"
        })

      %{id: domain_inside_note_2_id} =
        CacheHelpers.insert_domain(%{
          name: "domain_inside_note_2_name",
          external_id: "domain_inside_note_2_external_id"
        })

      insert(:data_structure_type, name: "type", template_id: 42)

      structure_1 = %{
        name: "TechName_1",
        path: ["foo", "bar"],
        template: %{"name" => "template"},
        note: %{
          "field_name" => %{"value" => ["field_value"], "origin" => "user"},
          "domain_inside_note_field" => %{
            "value" => [domain_inside_note_1_id, domain_inside_note_2_id],
            "origin" => "user"
          }
        },
        external_id: "ext_id",
        type: "type",
        data_structure_id: 8
      }

      structure_2 = %{
        name: "Alias Name 2",
        original_name: "TechName_2",
        alias: "Alias Name 2",
        path: ["foo", "bar"],
        template: %{"name" => "template"},
        note: %{
          "field_name" => %{"value" => ["field_value"], "origin" => "user"},
          "alias" => %{"value" => "Alias Name 2", "origin" => "user"}
        },
        external_id: "ext_id",
        type: "type",
        data_structure_id: 8
      }

      # Simulating structure_url_schema input from web and conversion for structures
      structure_url_schema = "https://truedat.td.dd/structure/:id"

      structure_1_url_schema_converted =
        "https://truedat.td.dd/structure/" <> to_string(structure_1.data_structure_id)

      structure_2_url_schema_converted =
        "https://truedat.td.dd/structure/" <> to_string(structure_2.data_structure_id)

      assert Download.to_editable_csv([structure_1, structure_2], structure_url_schema, @lang) ==
               """
               external_id;name;type;path;tech_name;alias_name;link_to_structure;field_name;domain_inside_note_field\r
               #{structure_1.external_id};#{structure_1.name};#{structure_1.type};#{Enum.join(structure_1.path, " > ")};#{structure_1.name};;#{structure_1_url_schema_converted};#{Map.get(Map.get(structure_1.note, "field_name"), "value")};domain_inside_note_1_external_id|domain_inside_note_2_external_id\r
               #{structure_2.external_id};#{structure_2.name};#{structure_2.type};#{Enum.join(structure_2.path, " > ")};#{structure_2.original_name};#{structure_2.alias};#{structure_2_url_schema_converted};#{Map.get(Map.get(structure_2.note, "field_name"), "value")};\r
               """
    end

    test "to_editable_csv return editable csv translated" do
      template_name = "Test i18n"
      template_id = 1

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
                "cardinality" => "?",
                "default" => %{"value" => "", "origin" => "default"},
                "label" => "label_i18n_test.dropdown.fixed",
                "name" => "i18n_test.dropdown.fixed",
                "subscribable" => false,
                "type" => "string",
                "values" => %{
                  "fixed" => [
                    "pear",
                    "banana"
                  ]
                },
                "widget" => "dropdown"
              },
              %{
                "cardinality" => "?",
                "default" => %{"value" => "", "origin" => "default"},
                "label" => "label_i18n_test_no_translate",
                "name" => "i18n_test_no_translate",
                "type" => "string",
                "values" => nil,
                "widget" => "string"
              },
              %{
                "cardinality" => "?",
                "default" => %{"value" => "", "origin" => "default"},
                "label" => "label_i18n_test.radio.fixed",
                "name" => "i18n_test.radio.fixed",
                "subscribable" => false,
                "type" => "string",
                "values" => %{
                  "fixed" => [
                    "pear",
                    "banana"
                  ]
                },
                "widget" => "radio"
              },
              %{
                "cardinality" => "*",
                "default" => %{"value" => "", "origin" => "default"},
                "label" => "label_i18n_test.checkbox.fixed_tuple",
                "name" => "i18n_test.checkbox.fixed_tuple",
                "subscribable" => false,
                "type" => "string",
                "values" => %{
                  "fixed_tuple" => [
                    %{
                      "text" => "pear",
                      "value" => "option_1"
                    },
                    %{
                      "text" => "banana",
                      "value" => "option_2"
                    }
                  ]
                },
                "widget" => "checkbox"
              }
            ]
          }
        ]
      })

      CacheHelpers.put_i18n_messages("es", [
        %{message_id: "fields.label_i18n_test.dropdown.fixed", definition: "Dropdown Fijo"},
        %{message_id: "fields.label_i18n_test.dropdown.fixed.pear", definition: "Pera"},
        %{message_id: "fields.label_i18n_test.dropdown.fixed.banana", definition: "Platano"},
        %{message_id: "fields.label_i18n_test.radio.fixed", definition: "Radio Fijo"},
        %{message_id: "fields.label_i18n_test.radio.fixed.pear", definition: "Pera"},
        %{message_id: "fields.label_i18n_test.radio.fixed.banana", definition: "Platano"},
        %{
          message_id: "fields.label_i18n_test.checkbox.fixed_tuple",
          definition: "Checkbox Tupla Fija"
        },
        %{message_id: "fields.label_i18n_test.checkbox.fixed_tuple.pear", definition: "Pera"},
        %{message_id: "fields.label_i18n_test.checkbox.fixed_tuple.banana", definition: "Platano"}
      ])

      insert(:data_structure_type, name: "type", template_id: template_id)

      structures = [
        %{
          name: "name",
          path: ["foo", "bar"],
          template: %{"name" => template_name},
          note: %{
            "i18n_test.dropdown.fixed" => %{"value" => "pear", "origin" => "user"},
            "i18n_test_no_translate" => %{"value" => "Test no translate", "origin" => "user"},
            "i18n_test.radio.fixed" => %{"value" => "banana", "origin" => "user"},
            "i18n_test.checkbox.fixed_tuple" => %{
              "value" => ["option_1", "option_2"],
              "origin" => "user"
            }
          },
          external_id: "ext_id",
          type: "type"
        }
      ]

      assert Download.to_editable_csv(structures, nil, @lang) ==
               """
               external_id;name;type;path;i18n_test.dropdown.fixed;i18n_test_no_translate;i18n_test.radio.fixed;i18n_test.checkbox.fixed_tuple\r
               ext_id;name;type;foo > bar;Pera;Test no translate;Platano;Pera|Platano\r
               """
    end
  end

  describe "Structure downloads with multiple fields" do
    test "to_editable_csv return csv content with multiple fields, to download" do
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
      %{id: domain_id_1} = CacheHelpers.insert_domain(external_id: "domain_1")
      %{id: domain_id_2} = CacheHelpers.insert_domain(external_id: "domain_2")

      structures = [
        %{
          name: "name",
          path: ["foo", "bar"],
          template: %{"name" => "template"},
          note: %{
            "field_numbers" => %{"value" => [1, 2], "origin" => "user"},
            "field_texts" => %{"value" => ["multi", "field"], "origin" => "user"},
            "field_text" => %{"value" => ["field"], "origin" => "user"},
            "field_domains" => %{"value" => [domain_id_1, domain_id_2], "origin" => "user"}
          },
          external_id: "ext_id",
          type: "type"
        }
      ]

      assert Download.to_editable_csv(structures, nil, @lang) ==
               """
               external_id;name;type;path;field_numbers;field_texts;field_text;field_domains\r
               ext_id;name;type;foo > bar;1|2;multi|field;field;domain_1|domain_2\r
               """
    end

    test "to_editable_csv will not return duplicated fields from templates" do
      CacheHelpers.insert_template(%{
        id: 51,
        name: "template1",
        label: "label1",
        scope: "dd",
        content: [
          %{
            "name" => "group",
            "fields" => [
              %{
                "name" => "field1",
                "type" => "string",
                "label" => "field1",
                "cardinality" => "1"
              },
              %{
                "name" => "field_dup",
                "type" => "string",
                "label" => "field_dup",
                "cardinality" => "1"
              }
            ]
          }
        ]
      })

      CacheHelpers.insert_template(%{
        id: 52,
        name: "template2",
        label: "label2",
        scope: "dd",
        content: [
          %{
            "name" => "group",
            "fields" => [
              %{
                "name" => "field2",
                "type" => "string",
                "label" => "field2",
                "cardinality" => "1"
              },
              %{
                "name" => "field_dup",
                "type" => "string",
                "label" => "field_dup",
                "cardinality" => "1"
              }
            ]
          }
        ]
      })

      insert(:data_structure_type, name: "type1", template_id: 51)
      insert(:data_structure_type, name: "type2", template_id: 52)

      structures = [
        %{
          name: "name1",
          path: ["foo", "bar"],
          note: %{
            "field1" => %{"value" => "1", "origin" => "user"},
            "field_dup" => %{"value" => "dup", "origin" => "user"}
          },
          external_id: "ext_id1",
          type: "type1"
        },
        %{
          name: "name2",
          path: ["foo", "bar"],
          note: %{
            "field2" => %{"value" => "2", "origin" => "user"},
            "field_dup" => %{"value" => "dup", "origin" => "user"}
          },
          external_id: "ext_id2",
          type: "type2"
        }
      ]

      assert Download.to_editable_csv(structures, nil, @lang) ==
               """
               external_id;name;type;path;field1;field_dup;field2\r
               ext_id1;name1;type1;foo > bar;1;dup;\r
               ext_id2;name2;type2;foo > bar;;dup;2\r
               """
    end
  end

  describe "Lineage download" do
    test "linage_to_csv/4 return csv content" do
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
        "metadata" => "Metadata"
      }

      metadata_string =
        grant_1
        |> get_in([:data_structure_version, :metadata])
        |> Jason.encode!()
        |> then(&Regex.replace(~r/"/, &1, fn _, _ -> "\"\"" end))
        |> then(&"\"#{&1}\"")

      assert Download.to_csv_grants(grants, header_labels) ==
               """
               User;Structure;Start date;End date;Metadata\r
               #{grant_1.user.full_name};#{grant_1.data_structure_version.name};#{grant_1.start_date};#{grant_1.end_date};#{metadata_string}\r
               """
    end
  end
end
