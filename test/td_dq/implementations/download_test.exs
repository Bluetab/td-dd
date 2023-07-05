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

  describe "Download.to_csv/3" do
    setup :create_template

    test "returns empty csv" do
      csv = Download.to_csv([], %{}, %{})
      assert csv == ""
    end

    test "returns csv content" do
      %{id: domain_id_1, name: domain_name_1} =
        CacheHelpers.insert_domain(external_id: "domain1", name: "imp_domain_1")

      %{id: domain_id_2} = CacheHelpers.insert_domain(external_id: "domain2")

      impl = %{
        implementation_key: "key1",
        implementation_type: "type1",
        domain_ids: [domain_id_1],
        executable: true,
        rule: %{
          df_content: %{
            system: [
              %{id: 1, name: "system", exernal_id: "exid"},
              %{id: 2, name: "system1", exernal_id: "exid1"}
            ],
            domains: [domain_id_1, domain_id_2],
            add_info1: ["field_value"]
          },
          df_name: "download",
          name: "Rule"
        },
        concepts: ["name"],
        execution_result_info: %{
          date: "2021-05-05T00:00:00Z",
          result_text: "quality_result.under_goal",
          result: "50.00"
        },
        goal: "12",
        minimum: "8",
        df_name: "impl_df_name",
        inserted_at: "2021-05-05T00:00:00Z",
        structure_domain_ids: [domain_id_1]
      }

      implementations = [impl]
      csv = Download.to_csv(implementations, @header_labels, @content_labels)

      assert csv ==
               """
               implementation_key;implementation_type;domain;Executable;rule;Rule Template Label;Implementation Template Label;goal;minimum;business_concepts;last_execution_at;records;errors;result;execution;inserted_at;structure_domains;Info;System;Domain\r
               #{impl.implementation_key};#{impl.implementation_type};#{domain_name_1};Executable;#{impl.rule.name};#{impl.rule.df_name};#{impl.df_name};#{impl.goal};#{impl.minimum};#{impl.concepts};#{Helpers.shift_zone(impl.execution_result_info.date)};;;#{impl.execution_result_info.result};Under Goal;#{Helpers.shift_zone(impl.inserted_at)};#{domain_name_1};field_value;system|system1;domain1|domain2\r
               """
    end

    test "handles uninformed result fields" do
      %{id: domain_id_1, name: domain_name_1} =
        CacheHelpers.insert_domain(external_id: "domain1", name: "imp_domain_1")

      impl = %{
        implementation_key: "foo",
        implementation_type: "bar",
        domain_ids: [domain_id_1],
        executable: true,
        rule: %{
          df_content: %{
            system: [
              %{id: 1, name: "system", exernal_id: "exid"},
              %{id: 2, name: "system1", exernal_id: "exid1"}
            ],
            add_info1: ["field_value"]
          },
          df_name: "download",
          name: "Rule"
        },
        concepts: ["name"],
        execution_result_info: nil,
        df_name: "impl_df_name_1",
        goal: "12",
        minimum: "8",
        inserted_at: "2020-05-05T00:00:00Z",
        structure_domain_ids: []
      }

      impl1 = %{
        implementation_key: "baz",
        implementation_type: "xyz",
        domain_ids: [domain_id_1],
        executable: false,
        rule: %{
          df_content: %{
            system: [
              %{id: 1, name: "system", exernal_id: "exid"},
              %{id: 2, name: "system1", exernal_id: "exid1"}
            ],
            add_info1: ["field_value"]
          },
          df_name: "download",
          name: "Rule"
        },
        concepts: ["name"],
        execution_result_info: %{
          date: "2021-05-05T00:00:00Z",
          result: "40.00"
        },
        df_name: "impl_df_name_2",
        goal: "12",
        minimum: "8",
        inserted_at: "2021-05-05T00:00:00Z",
        structure_domain_ids: []
      }

      csv = Download.to_csv([impl, impl1], @header_labels, @content_labels)

      assert csv ==
               """
               implementation_key;implementation_type;domain;Executable;rule;Rule Template Label;Implementation Template Label;goal;minimum;business_concepts;last_execution_at;records;errors;result;execution;inserted_at;structure_domains;Info;System;Domain\r
               #{impl.implementation_key};#{impl.implementation_type};#{domain_name_1};Executable;#{impl.rule.name};#{impl.rule.df_name};#{impl.df_name};#{impl.goal};#{impl.minimum};#{impl.concepts};;;;;;#{Helpers.shift_zone(impl.inserted_at)};;field_value;system|system1;\r
               #{impl1.implementation_key};#{impl1.implementation_type};#{domain_name_1};Internal;#{impl1.rule.name};#{impl1.rule.df_name};#{impl1.df_name};#{impl1.goal};#{impl1.minimum};#{impl1.concepts};#{Helpers.shift_zone(impl1.execution_result_info.date)};;;#{impl1.execution_result_info.result};;#{Helpers.shift_zone(impl1.inserted_at)};;field_value;system|system1;\r
               """
    end

    test "handles ruleless implementations" do
      %{id: domain_id_1, name: domain_name_1} =
        CacheHelpers.insert_domain(external_id: "domain1", name: "imp_domain_1")

      impl = %{
        domain_ids: [domain_id_1],
        concepts: ["name"],
        df_content: %{
          system: [
            %{id: 1, name: "system", exernal_id: "exid"},
            %{id: 2, name: "system1", exernal_id: "exid1"}
          ],
          add_info1: ["field_value"]
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
        structure_domain_ids: [],
        minimum: "8"
      }

      implementations = [impl]
      csv = Download.to_csv(implementations, @header_labels, @content_labels)

      assert csv ==
               """
               implementation_key;implementation_type;domain;Executable;rule;Rule Template Label;Implementation Template Label;goal;minimum;business_concepts;last_execution_at;records;errors;result;execution;inserted_at;structure_domains;Info;System;Domain\r
               #{impl.implementation_key};#{impl.implementation_type};#{domain_name_1};Executable;;;#{impl.df_name};#{impl.goal};#{impl.minimum};#{impl.concepts};#{Helpers.shift_zone(impl.execution_result_info.date)};;;#{impl.execution_result_info.result};Under Goal;#{Helpers.shift_zone(impl.inserted_at)};;field_value;system|system1;\r
               """
    end
  end
end
