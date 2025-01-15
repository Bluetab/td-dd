defmodule TdDq.Implementations.DownloadTest do
  use TdDd.DataCase

  alias TdDd.Helpers
  alias TdDq.Implementations.Download

  @content_labels %{
    "quality_result.under_goal" => "Under Goal",
    "executable.false" => "Internal",
    "executable.true" => "Executable"
  }

  @header_labels %{
    "rule_template" => "Rule Template Label",
    "implementation_template" => "Implementation Template Label",
    "executable" => "Executable"
  }

  defp create_template(_) do
    template =
      CacheHelpers.insert_template(
        name: "download",
        label: "label",
        scope: "dq",
        content: [
          %{
            "name" => "group",
            "fields" => [
              %{
                "name" => "add_info1",
                "type" => "list",
                "label" => "Info"
              },
              %{
                "name" => "system",
                "type" => "system",
                "label" => "System"
              },
              %{
                "name" => "domains",
                "type" => "domain",
                "label" => "Domain",
                "cardinality" => "*"
              }
            ]
          }
        ]
      )

    [template: template]
  end

  defp create_concept(_) do
    [concept: CacheHelpers.insert_concept(name: "name")]
  end

  describe "Download.to_csv/3" do
    setup :create_template
    setup :create_concept

    test "returns empty csv" do
      csv = Download.to_csv([], %{}, %{}, "es")
      assert csv == ""
    end

    test "returns csv content with domain name from template", %{concept: concept} do
      %{id: domain_id_1, name: domain_name_1} =
        CacheHelpers.insert_domain(external_id: "domain1", name: "domain_name_1")

      %{id: domain_id_2} =
        CacheHelpers.insert_domain(external_id: "domain2", name: "domain_name_2")

      impl = %{
        implementation_key: "key1",
        implementation_type: "type1",
        domain_ids: [domain_id_1],
        executable: true,
        rule: %{
          df_content: %{
            system: %{
              "value" => [
                %{id: 1, name: "system", exernal_id: "exid"},
                %{id: 2, name: "system1", exernal_id: "exid1"}
              ],
              "origin" => "user"
            },
            domains: %{"value" => [domain_id_1, domain_id_2], "origin" => "user"},
            add_info1: %{"value" => ["field_value"], "origin" => "user"}
          },
          df_name: "download",
          name: "Rule"
        },
        concepts: [concept.id],
        execution_result_info: %{
          date: "2021-05-05T00:00:00Z",
          result_text: "quality_result.under_goal",
          result: "50.00"
        },
        goal: "12",
        minimum: "8",
        df_name: "impl_df_name",
        inserted_at: "2021-05-05T00:00:00Z",
        updated_at: "2020-05-05T01:00:00Z",
        structure_domain_ids: [domain_id_1]
      }

      lang = "es"

      implementations = [impl]
      csv = Download.to_csv(implementations, @header_labels, @content_labels, lang)

      assert csv ==
               """
               implementation_key;implementation_type;domain;Executable;rule;Rule Template Label;Implementation Template Label;goal;minimum;business_concepts;last_execution_at;records;errors;result;execution;inserted_at;updated_at;structure_domains;Info;System;Domain\r
               #{impl.implementation_key};#{impl.implementation_type};#{domain_name_1};Executable;#{impl.rule.name};#{impl.rule.df_name};#{impl.df_name};#{impl.goal};#{impl.minimum};#{concept.name};#{Helpers.shift_zone(impl.execution_result_info.date)};;;#{impl.execution_result_info.result};Under Goal;#{Helpers.shift_zone(impl.inserted_at)};#{Helpers.shift_zone(impl.updated_at)};#{domain_name_1};field_value;system|system1;domain_name_1|domain_name_2\r
               """
    end

    test "handles uninformed result fields", %{concept: concept} do
      %{id: domain_id_1, name: domain_name_1} =
        CacheHelpers.insert_domain(external_id: "domain1", name: "imp_domain_1")

      impl = %{
        implementation_key: "foo",
        implementation_type: "bar",
        domain_ids: [domain_id_1],
        executable: true,
        rule: %{
          df_content: %{
            system: %{
              "value" => [
                %{id: 1, name: "system", exernal_id: "exid"},
                %{id: 2, name: "system1", exernal_id: "exid1"}
              ],
              "origin" => "user"
            },
            add_info1: %{"value" => ["field_value"], "origin" => "user"}
          },
          df_name: "download",
          name: "Rule"
        },
        concepts: [concept.id],
        execution_result_info: nil,
        df_name: "impl_df_name_1",
        goal: "12",
        minimum: "8",
        inserted_at: "2020-05-05T00:00:00Z",
        updated_at: "2020-05-05T01:00:00Z",
        structure_domain_ids: []
      }

      impl1 = %{
        implementation_key: "baz",
        implementation_type: "xyz",
        domain_ids: [domain_id_1],
        executable: false,
        rule: %{
          df_content: %{
            system: %{
              "value" => [
                %{id: 1, name: "system", exernal_id: "exid"},
                %{id: 2, name: "system1", exernal_id: "exid1"}
              ],
              "origin" => "user"
            },
            add_info1: %{"value" => ["field_value"], "origin" => "user"}
          },
          df_name: "download",
          name: "Rule"
        },
        concepts: [concept.id],
        execution_result_info: %{
          date: "2021-05-05T00:00:00Z",
          result: "40.00"
        },
        df_name: "impl_df_name_2",
        goal: "12",
        minimum: "8",
        inserted_at: "2021-05-05T00:00:00Z",
        updated_at: "2020-05-05T01:00:00Z",
        structure_domain_ids: []
      }

      lang = "es"

      csv = Download.to_csv([impl, impl1], @header_labels, @content_labels, lang)

      assert csv ==
               """
               implementation_key;implementation_type;domain;Executable;rule;Rule Template Label;Implementation Template Label;goal;minimum;business_concepts;last_execution_at;records;errors;result;execution;inserted_at;updated_at;structure_domains;Info;System;Domain\r
               #{impl.implementation_key};#{impl.implementation_type};#{domain_name_1};Executable;#{impl.rule.name};#{impl.rule.df_name};#{impl.df_name};#{impl.goal};#{impl.minimum};#{concept.name};;;;;;#{Helpers.shift_zone(impl.inserted_at)};#{Helpers.shift_zone(impl.updated_at)};;field_value;system|system1;\r
               #{impl1.implementation_key};#{impl1.implementation_type};#{domain_name_1};Internal;#{impl1.rule.name};#{impl1.rule.df_name};#{impl1.df_name};#{impl1.goal};#{impl1.minimum};#{concept.name};#{Helpers.shift_zone(impl1.execution_result_info.date)};;;#{impl1.execution_result_info.result};;#{Helpers.shift_zone(impl1.inserted_at)};#{Helpers.shift_zone(impl1.updated_at)};;field_value;system|system1;\r
               """
    end

    test "handles ruleless implementations", %{concept: concept} do
      %{id: domain_id_1, name: domain_name_1} =
        CacheHelpers.insert_domain(external_id: "domain1", name: "imp_domain_1")

      impl = %{
        domain_ids: [domain_id_1],
        concepts: [concept.id],
        df_content: %{
          system: %{
            "value" => [
              %{id: 1, name: "system", exernal_id: "exid"},
              %{id: 2, name: "system1", exernal_id: "exid1"}
            ],
            "origin" => "user"
          },
          add_info1: %{"value" => ["field_value"], "origin" => "user"}
        },
        df_name: "download",
        executable: true,
        execution_result_info: %{
          date: "2021-05-05T00:00:00Z",
          result_text: "quality_result.under_goal",
          result: "50.00"
        },
        goal: "12",
        implementation_key: "key1",
        implementation_type: "type1",
        inserted_at: "2021-05-05T00:00:00Z",
        updated_at: "2021-05-05T01:00:00Z",
        structure_domain_ids: [],
        minimum: "8"
      }

      lang = "es"

      implementations = [impl]
      csv = Download.to_csv(implementations, @header_labels, @content_labels, lang)

      assert csv ==
               """
               implementation_key;implementation_type;domain;Executable;rule;Rule Template Label;Implementation Template Label;goal;minimum;business_concepts;last_execution_at;records;errors;result;execution;inserted_at;updated_at;structure_domains;Info;System;Domain\r
               #{impl.implementation_key};#{impl.implementation_type};#{domain_name_1};Executable;;;#{impl.df_name};#{impl.goal};#{impl.minimum};#{concept.name};#{Helpers.shift_zone(impl.execution_result_info.date)};;;#{impl.execution_result_info.result};Under Goal;#{Helpers.shift_zone(impl.inserted_at)};#{Helpers.shift_zone(impl.updated_at)};;field_value;system|system1;\r
               """
    end

    test "handles ruleless implementations with translations", %{concept: concept} do
      %{id: domain_id_1, name: domain_name_1} =
        CacheHelpers.insert_domain(external_id: "domain1", name: "imp_domain_1")

      impl = %{
        domain_ids: [domain_id_1],
        concepts: [concept.id],
        df_content: %{
          system: %{
            "value" => [
              %{id: 1, name: "system", exernal_id: "exid"},
              %{id: 2, name: "system1", exernal_id: "exid1"}
            ],
            "origin" => "user"
          },
          add_info1: %{"value" => ["field_value"], "origin" => "user"}
        },
        df_name: "download",
        executable: true,
        execution_result_info: %{
          date: "2021-05-05T00:00:00Z",
          result_text: "quality_result.under_goal",
          result: "50.00"
        },
        goal: "12",
        implementation_key: "key1",
        implementation_type: "type1",
        inserted_at: "2021-05-05T00:00:00Z",
        updated_at: "2021-05-05T01:00:00Z",
        structure_domain_ids: [],
        minimum: "8"
      }

      lang = "es"

      CacheHelpers.put_i18n_messages(lang, [
        %{message_id: "ruleImplementations.props.records", definition: "Registros"},
        %{message_id: "ruleImplementations.props.errors", definition: "Errores"}
      ])

      implementations = [impl]
      csv = Download.to_csv(implementations, @header_labels, @content_labels, lang)

      assert csv ==
               """
               implementation_key;implementation_type;domain;Executable;rule;Rule Template Label;Implementation Template Label;goal;minimum;business_concepts;last_execution_at;Registros;Errores;result;execution;inserted_at;updated_at;structure_domains;Info;System;Domain\r
               #{impl.implementation_key};#{impl.implementation_type};#{domain_name_1};Executable;;;#{impl.df_name};#{impl.goal};#{impl.minimum};#{concept.name};#{Helpers.shift_zone(impl.execution_result_info.date)};;;#{impl.execution_result_info.result};Under Goal;#{Helpers.shift_zone(impl.inserted_at)};#{Helpers.shift_zone(impl.updated_at)};;field_value;system|system1;\r
               """
    end
  end
end
