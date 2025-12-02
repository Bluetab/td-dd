defmodule TdDq.XLSX.WriterTest do
  use TdDd.DataCase

  alias TdCore.Utils.CollectionUtils
  alias TdDq.XLSX.Writer

  describe "TdDq.XLSX.Writer.rows_by_implementation_template/3" do
    test "test returns the implementations content split by template for download" do
      domain = CacheHelpers.insert_domain()

      %{name: template_name_1} =
        template_1 =
        CacheHelpers.insert_template(%{
          name: "template_1",
          scope: "dq",
          content: [
            %{
              "name" => "group",
              "fields" => [
                %{
                  "name" => "field_name",
                  "type" => "string",
                  "label" => "Label field_name"
                },
                %{
                  "name" => "table_field",
                  "type" => "table",
                  "widget" => "table",
                  "label" => "Label table_field",
                  "values" => %{
                    "table_columns" => [
                      %{"mandatory" => false, "name" => "Col A"},
                      %{"mandatory" => false, "name" => "Col B"}
                    ]
                  }
                }
              ]
            }
          ]
        })

      %{
        implementation_key: key_0,
        implementation_type: type_0,
        rule: %{name: name_0},
        result_type: _result_type_0,
        goal: goal_0,
        minimum: minimum_0,
        inserted_at: inserted_0,
        updated_at: updated_0,
        df_content: %{
          field_name: %{"value" => template_value_0}
        },
        dataset: [
          %TdDq.Implementations.DatasetRow{
            structure: %TdDq.Implementations.Structure{
              id: dataset_0_id_0
            }
          },
          %TdDq.Implementations.DatasetRow{
            structure: %TdDq.Implementations.Structure{
              id: dataset_0_id_1
            }
          }
        ],
        validation: [
          %TdDq.Implementations.Conditions{
            conditions: [
              %TdDq.Implementations.ConditionRow{
                structure: %TdDq.Implementations.Structure{
                  id: id_validation_0
                }
              }
            ]
          }
        ]
      } =
        implementation_0_type_1 =
        insert(:implementation,
          implementation_key: "imp_0",
          df_name: template_name_1,
          df_content: %{
            field_name: %{"value" => "some name"},
            table_field: %{
              "value" => [
                %{"Col A" => "hola", "Col B" => "que tal"},
                %{"Col A" => "como", "Col B" => "estas"}
              ]
            }
          },
          template: template_1,
          domain_id: domain.id,
          domain: domain
        )

      %{name: template_name_2} =
        template_2 =
        CacheHelpers.insert_template(%{
          name: "template_2",
          scope: "dq",
          content: [
            %{
              "name" => "group",
              "fields" => [
                %{
                  "name" => "foo",
                  "type" => "string",
                  "label" => "Label foo"
                }
              ]
            }
          ]
        })

      %{
        implementation_key: key_1,
        implementation_type: type_1,
        rule: %{name: name_1},
        result_type: _result_type_1,
        goal: goal_1,
        minimum: minimum_1,
        inserted_at: inserted_1,
        updated_at: updated_1,
        df_content: %{foo: template_value_1},
        dataset: [
          %TdDq.Implementations.DatasetRow{
            structure: %TdDq.Implementations.Structure{
              id: dataset_1_id_0
            }
          },
          %TdDq.Implementations.DatasetRow{
            structure: %TdDq.Implementations.Structure{
              id: dataset_1_id_1
            }
          }
        ],
        validation: [
          %TdDq.Implementations.Conditions{
            conditions: [
              %TdDq.Implementations.ConditionRow{
                structure: %TdDq.Implementations.Structure{
                  id: id_validation_1
                }
              }
            ]
          }
        ]
      } =
        implementation_1_type_2 =
        insert(:implementation,
          implementation_key: "imp_1",
          df_name: template_name_2,
          df_content: %{foo: "foo_1 name"},
          template: template_2,
          domain_id: domain.id,
          domain: domain
        )

      %{
        implementation_key: key_2,
        implementation_type: type_2,
        rule: %{name: name_2},
        result_type: _result_type_2,
        goal: goal_2,
        minimum: minimum_2,
        inserted_at: inserted_2,
        updated_at: updated_2,
        df_content: %{foo: template_value_2},
        dataset: [
          %TdDq.Implementations.DatasetRow{
            structure: %TdDq.Implementations.Structure{
              id: dataset_2_id_0
            }
          },
          %TdDq.Implementations.DatasetRow{
            structure: %TdDq.Implementations.Structure{
              id: dataset_2_id_1
            }
          }
        ],
        validation: [
          %TdDq.Implementations.Conditions{
            conditions: [
              %TdDq.Implementations.ConditionRow{
                structure: %TdDq.Implementations.Structure{
                  id: id_validation_2
                }
              }
            ]
          }
        ]
      } =
        implementation_2_type_2 =
        insert(:implementation,
          implementation_key: "imp_2",
          df_name: template_name_2,
          df_content: %{foo: "foo_2 name"},
          template: template_2,
          domain_id: domain.id,
          domain: domain
        )

      stringify_implementation = fn impl, template ->
        impl
        |> CollectionUtils.stringify_keys(true)
        |> Map.put("template", template)
      end

      implementations_type_2 =
        Enum.map(
          [
            implementation_1_type_2,
            implementation_2_type_2
          ],
          &stringify_implementation.(&1, template_2)
        )

      implementation_information =
        %{
          template_name_1 => [
            stringify_implementation.(implementation_0_type_1, template_1)
          ],
          template_name_2 => implementations_type_2
        }

      rows =
        Writer.rows_by_implementation_template(implementation_information)

      assert [headers | content] = rows["template_1"]

      assert Enum.count(headers) == 25

      assert Enum.take(headers, 11) == [
               ["implementation_key", {:bg_color, "#ffd428"}],
               ["implementation_type"],
               ["domain_external_id", {:bg_color, "#ffd428"}],
               ["domain"],
               ["executable"],
               ["rule"],
               ["rule_template"],
               ["implementation_template", {:bg_color, "#ffd428"}],
               ["result_type", {:bg_color, "#ffd428"}],
               ["goal", {:bg_color, "#ffd428"}],
               ["minimum", {:bg_color, "#ffd428"}]
             ]

      assert ["Label field_name", {:bg_color, "#ffe994"}] ==
               Enum.find(headers, fn
                 [header, _] -> header == "Label field_name"
                 _ -> false
               end)

      assert ["Label table_field", {:bg_color, "#ffe994"}] ==
               Enum.find(headers, fn
                 [header, _] -> header == "Label table_field"
                 _ -> false
               end)

      assert content == [
               [
                 key_0,
                 type_0,
                 domain.external_id,
                 domain.name,
                 "ruleImplementation.props.executable.true",
                 name_0,
                 "",
                 template_name_1,
                 "ruleImplementations.props.result_type.percentage",
                 to_string(goal_0),
                 to_string(minimum_0),
                 "",
                 "",
                 "",
                 "",
                 "",
                 TdDd.Helpers.shift_zone(inserted_0),
                 TdDd.Helpers.shift_zone(updated_0),
                 "",
                 "",
                 template_value_0,
                 [
                   "Col A;Col B\nhola;que tal\ncomo;estas",
                   {:align_vertical, :top}
                 ],
                 "dataset_structure_id:/#{dataset_0_id_0}",
                 "dataset_structure_id:/#{dataset_0_id_1}",
                 "validation_structure_id:/#{id_validation_0}",
                 ""
               ]
             ]

      assert [headers | content] = rows["template_2"]

      assert Enum.count(headers) == 24

      assert Enum.take(headers, 11) == [
               ["implementation_key", {:bg_color, "#ffd428"}],
               ["implementation_type"],
               ["domain_external_id", {:bg_color, "#ffd428"}],
               ["domain"],
               ["executable"],
               ["rule"],
               ["rule_template"],
               ["implementation_template", {:bg_color, "#ffd428"}],
               ["result_type", {:bg_color, "#ffd428"}],
               ["goal", {:bg_color, "#ffd428"}],
               ["minimum", {:bg_color, "#ffd428"}]
             ]

      assert ["Label foo", {:bg_color, "#ffe994"}] ==
               Enum.find(
                 headers,
                 fn
                   [header, _] -> header == "Label foo"
                   _ -> false
                 end
               )

      assert content == [
               [
                 key_1,
                 type_1,
                 domain.external_id,
                 domain.name,
                 "ruleImplementation.props.executable.true",
                 name_1,
                 "",
                 template_name_2,
                 "ruleImplementations.props.result_type.percentage",
                 to_string(goal_1),
                 to_string(minimum_1),
                 "",
                 "",
                 "",
                 "",
                 "",
                 TdDd.Helpers.shift_zone(inserted_1),
                 TdDd.Helpers.shift_zone(updated_1),
                 "",
                 "",
                 template_value_1,
                 "dataset_structure_id:/#{dataset_1_id_0}",
                 "dataset_structure_id:/#{dataset_1_id_1}",
                 "validation_structure_id:/#{id_validation_1}",
                 ""
               ],
               [
                 key_2,
                 type_2,
                 domain.external_id,
                 domain.name,
                 "ruleImplementation.props.executable.true",
                 name_2,
                 "",
                 template_name_2,
                 "ruleImplementations.props.result_type.percentage",
                 to_string(goal_2),
                 to_string(minimum_2),
                 "",
                 "",
                 "",
                 "",
                 "",
                 TdDd.Helpers.shift_zone(inserted_2),
                 TdDd.Helpers.shift_zone(updated_2),
                 "",
                 "",
                 template_value_2,
                 "dataset_structure_id:/#{dataset_2_id_0}",
                 "dataset_structure_id:/#{dataset_2_id_1}",
                 "validation_structure_id:/#{id_validation_2}",
                 ""
               ]
             ]
    end
  end
end
