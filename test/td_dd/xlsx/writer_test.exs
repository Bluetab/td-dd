defmodule TdDd.XLSX.WriterTest do
  use TdDd.DataCase

  alias TdDd.XLSX.Writer

  describe "TdDd.XLSX.Writer.data_structure_type_information/2" do
    test "returns content fields and structures grouped by structure type for published notes" do
      %{id: id, content: [%{"fields" => content_fields_for_type_1}]} =
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
        data_structure_id: 0
      }

      %{id: id, content: [%{"fields" => content_fields_for_type_2}]} =
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
        path: ["foo", "bar"],
        template: %{"name" => "template_2"},
        note: %{"bar" => %{"value" => ["field_value"], "origin" => "user"}},
        external_id: "ext_id",
        type: "type_2",
        data_structure_id: 1,
        metadata: %{"alias" => "PostgreSQL"}
      }

      assert content_fields_by_type =
               %{} =
               Writer.data_structure_type_information([structure_type_1, structure_type_2])

      information_for_type_1 = %{structures: [structure_type_1], metadata: []}
      information_for_type_2 = %{structures: [structure_type_2], metadata: ["metadata:alias"]}

      assert content_fields_by_type["type_1"] == information_for_type_1
      assert content_fields_by_type["type_2"] == information_for_type_2

      assert content_fields_by_type =
               %{} =
               Writer.data_structure_type_information([structure_type_1, structure_type_2],
                 download_type: :editable
               )

      information_for_type_1 = %{
        content: content_fields_for_type_1,
        structures: [structure_type_1]
      }

      information_for_type_2 = %{
        content: content_fields_for_type_2,
        structures: [structure_type_2]
      }

      assert content_fields_by_type["type_1"] == information_for_type_1
      assert content_fields_by_type["type_2"] == information_for_type_2
    end

    test "returns content fields and structures grouped by structure type for non-published notes" do
      %{id: id, content: [%{"fields" => content_fields_for_type_1}]} =
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
        data_structure_id: 0
      }

      %{id: id, content: [%{"fields" => content_fields_for_type_2}]} =
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
        path: ["foo", "bar"],
        template: %{"name" => "template_2"},
        non_published_note: %{
          "note" => %{"bar" => %{"value" => ["field_value"], "origin" => "user"}}
        },
        external_id: "ext_id",
        type: "type_2",
        data_structure_id: 1,
        metadata: %{"alias" => "PostgreSQL"}
      }

      assert content_fields_by_type =
               %{} =
               Writer.data_structure_type_information([structure_type_1, structure_type_2])

      information_for_type_1 = %{structures: [structure_type_1], metadata: []}
      information_for_type_2 = %{structures: [structure_type_2], metadata: ["metadata:alias"]}

      assert content_fields_by_type["type_1"] == information_for_type_1
      assert content_fields_by_type["type_2"] == information_for_type_2

      assert content_fields_by_type =
               %{} =
               Writer.data_structure_type_information([structure_type_1, structure_type_2],
                 download_type: :editable
               )

      information_for_type_1 = %{
        content: content_fields_for_type_1,
        structures: [structure_type_1]
      }

      information_for_type_2 = %{
        content: content_fields_for_type_2,
        structures: [structure_type_2]
      }

      assert content_fields_by_type["type_1"] == information_for_type_1
      assert content_fields_by_type["type_2"] == information_for_type_2
    end
  end

  describe "TdDd.XLSX.Writer.rows_by_structure_type/3" do
    test "test returns the the published notes content split by type for editable download" do
      domain = CacheHelpers.insert_domain()

      %{id: id, content: [%{"fields" => content_fields_for_type_1}]} =
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
                },
                %{
                  "name" => "alias",
                  "type" => "string",
                  "label" => "alias",
                  "cardinality" => "?"
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
          "alias" => %{"value" => "alias_value", "origin" => "user"},
          "domain_inside_note_field" => %{
            "value" => [],
            "origin" => "user"
          }
        },
        external_id: "ext_id",
        type: "type_1",
        data_structure_id: 0,
        domain_ids: [domain.id],
        system: %{"name" => "system_1"}
      }

      %{id: id, content: [%{"fields" => content_fields_for_type_2}]} =
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

      information_for_type_1 = %{
        content: content_fields_for_type_1,
        structures: [structure_type_1]
      }

      information_for_type_2 = %{
        content: content_fields_for_type_2,
        structures: [structure_type_2]
      }

      information_by_type = %{
        "type_1" => information_for_type_1,
        "type_2" => information_for_type_2
      }

      rows =
        Writer.rows_by_structure_type(information_by_type, "https://truedat.td.dd/structure/:id",
          download_type: :editable,
          note_type: :published
        )

      assert [headers | content] = rows["type_1"]
      assert Enum.count(headers) == 12

      assert Enum.take(headers, 9) == [
               ["external_id", {:bg_color, "#ffd428"}],
               "name",
               "tech_name",
               "alias_name",
               "link_to_structure",
               "domain",
               "type",
               "system",
               "path"
             ]

      assert ["field_name", {:bg_color, "#ffe994"}] ==
               Enum.find(headers, fn
                 [header, _] -> header == "field_name"
                 _ -> false
               end)

      assert ["domain_inside_note_field", {:bg_color, "#ffe994"}] ==
               Enum.find(
                 headers,
                 fn
                   [header, _] -> header == "domain_inside_note_field"
                   _ -> false
                 end
               )

      assert ["alias", {:bg_color, "#ffe994"}] ==
               Enum.find(
                 headers,
                 fn
                   [header, _] -> header == "alias"
                   _ -> false
                 end
               )

      assert content == [
               [
                 "ext_id",
                 "TechName_1",
                 "TechName_1",
                 "alias_value",
                 "https://truedat.td.dd/structure/0",
                 domain.name,
                 "type_1",
                 "system_1",
                 "foo > bar",
                 "field_value",
                 "",
                 "alias_value"
               ]
             ]

      assert [headers | content] = rows["type_2"]

      assert Enum.count(headers) == 10

      assert Enum.take(headers, 9) == [
               ["external_id", {:bg_color, "#ffd428"}],
               "name",
               "tech_name",
               "alias_name",
               "link_to_structure",
               "domain",
               "type",
               "system",
               "path"
             ]

      assert ["bar", {:bg_color, "#ffe994"}] ==
               Enum.find(
                 headers,
                 fn
                   [header, _] -> header == "bar"
                   _ -> false
                 end
               )

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

    test "test returns the non-published notes content split by type for editable download" do
      domain = CacheHelpers.insert_domain()

      %{id: id, content: [%{"fields" => content_fields_for_type_1}]} =
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
                },
                %{
                  "name" => "alias",
                  "type" => "string",
                  "label" => "alias",
                  "cardinality" => "?"
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
            "alias" => %{"value" => "alias_value", "origin" => "user"},
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

      %{id: id, content: [%{"fields" => content_fields_for_type_2}]} =
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

      information_for_type_1 = %{
        content: content_fields_for_type_1,
        structures: [structure_type_1]
      }

      information_for_type_2 = %{
        content: content_fields_for_type_2,
        structures: [structure_type_2]
      }

      information_by_type = %{
        "type_1" => information_for_type_1,
        "type_2" => information_for_type_2
      }

      rows =
        Writer.rows_by_structure_type(information_by_type, "https://truedat.td.dd/structure/:id",
          download_type: :editable,
          note_type: :non_published
        )

      assert [headers | content] = rows["type_1"]
      assert Enum.count(headers) == 12

      assert Enum.take(headers, 9) == [
               ["external_id", {:bg_color, "#ffd428"}],
               "name",
               "tech_name",
               "alias_name",
               "link_to_structure",
               "domain",
               "type",
               "system",
               "path"
             ]

      assert ["field_name", {:bg_color, "#ffe994"}] ==
               Enum.find(headers, fn
                 [header, _] -> header == "field_name"
                 _ -> false
               end)

      assert ["domain_inside_note_field", {:bg_color, "#ffe994"}] ==
               Enum.find(
                 headers,
                 fn
                   [header, _] -> header == "domain_inside_note_field"
                   _ -> false
                 end
               )

      assert ["alias", {:bg_color, "#ffe994"}] ==
               Enum.find(
                 headers,
                 fn
                   [header, _] -> header == "alias"
                   _ -> false
                 end
               )

      assert content == [
               [
                 "ext_id",
                 "TechName_1",
                 "TechName_1",
                 "alias_value",
                 "https://truedat.td.dd/structure/0",
                 domain.name,
                 "type_1",
                 "system_1",
                 "foo > bar",
                 "field_value",
                 "",
                 "alias_value"
               ]
             ]

      assert [headers | content] = rows["type_2"]

      assert Enum.count(headers) == 10

      assert Enum.take(headers, 9) == [
               ["external_id", {:bg_color, "#ffd428"}],
               "name",
               "tech_name",
               "alias_name",
               "link_to_structure",
               "domain",
               "type",
               "system",
               "path"
             ]

      assert ["bar", {:bg_color, "#ffe994"}] ==
               Enum.find(
                 headers,
                 fn
                   [header, _] -> header == "bar"
                   _ -> false
                 end
               )

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

    test "test returns the published notes content split by type for non-editable download" do
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
        description: "description_1",
        inserted_at: "inserted_at_1",
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
        group: "group_2",
        system: %{"name" => "system_2"},
        description: "description_2",
        inserted_at: "inserted_at_2",
        domain_ids: [domain.id],
        metadata: %{"alias" => "PostgreSQL", "masking_policy" => %{"0" => %{"foo" => "bar"}}}
      }

      information_for_type_1 = %{
        structures: [structure_type_1],
        metadata: []
      }

      information_for_type_2 = %{
        metadata: ["metadata:alias", "metadata:masking_policy"],
        structures: [structure_type_2]
      }

      information_by_type = %{
        "type_1" => information_for_type_1,
        "type_2" => information_for_type_2
      }

      rows =
        Writer.rows_by_structure_type(information_by_type, "https://truedat.td.dd/structure/:id")

      assert [headers | content] = rows["type_1"]

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
                 "inserted_at_1"
               ]
             ]

      assert [headers | content] = rows["type_2"]

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
               "metadata:alias",
               "metadata:masking_policy"
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
                 "inserted_at_2",
                 "PostgreSQL",
                 Jason.encode!(%{"0" => %{"foo" => "bar"}})
               ]
             ]
    end

    test "takes header labels into account if provided" do
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
        description: "description_1",
        inserted_at: "inserted_at_1",
        domain_ids: [domain.id]
      }

      information_for_type_1 = %{
        structures: [structure_type_1],
        metadata: ["metadata:alias"]
      }

      header_labels = %{
        "type" => "Tipo",
        "tech_name" => "Nombre Técnico",
        "alias_name" => "Alias",
        "link_to_structure" => "Link a la estructura",
        "external_id" => "Id Externo",
        "group" => "Grupo",
        "domain" => "Dominio",
        "system" => "Sistema",
        "metadata" => "Metadata",
        "path" => "Ruta",
        "description" => "Descripción",
        "inserted_at" => "Insertado",
        "deleted_at" => "Borrado"
      }

      information_by_type = %{
        "type_1" => information_for_type_1
      }

      rows =
        Writer.rows_by_structure_type(information_by_type, "https://truedat.td.dd/structure/:id",
          header_labels: header_labels
        )

      assert [headers | _content] = rows["type_1"]

      assert headers == [
               "Tipo",
               "name",
               "Nombre Técnico",
               "Alias",
               "Link a la estructura",
               "Grupo",
               "Dominio",
               "Sistema",
               "Ruta",
               "Descripción",
               "Id Externo",
               "Insertado",
               "Metadata:alias"
             ]
    end
  end
end
