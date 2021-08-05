defmodule TdDq.DownloadTest do
  @moduledoc """
  Tests download of implementations in csv format
  """
  use TdDd.DataCase

  alias TdCache.TemplateCache
  alias TdDq.Implementations.Download

  defp create_template(_) do
    template = %{
      id: System.unique_integer([:positive]),
      name: "download",
      label: "label",
      scope: "dq",
      updated_at: DateTime.utc_now(),
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
            }
          ]
        }
      ]
    }

    TemplateCache.put(template)

    on_exit(fn ->
      TemplateCache.delete(template.id)
    end)

    {:ok, template: template}
  end

  describe "Implementations download" do
    setup :create_template

    test "download empty csv" do
      csv = Download.to_csv([], %{}, %{})
      assert csv == ""
    end

    test "to_csv/1 return csv content to download" do
      content_labels = %{
        "quality_result.under_goal" => "Under Goal",
        "executable.false" => "Internal",
        "executable.true" => "Executable"
      }

      header_labels = %{"template" => "Template Label", "executable" => "Executable"}

      impl = %{
        implementation_key: "key1",
        implementation_type: "type1",
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
          name: "Rule",
          goal: "12",
          minimum: "8"
        },
        current_business_concept_version: %{
          name: "name"
        },
        execution_result_info: %{
          date: "2018-05-05",
          result_text: "quality_result.under_goal",
          result: "50.00"
        },
        inserted_at: "2020-05-05"
      }

      implementations = [impl]
      csv = Download.to_csv(implementations, header_labels, content_labels)

      assert csv ==
               """
               implementation_key;implementation_type;Executable;rule;Template Label;goal;minimum;business_concept;last_execution_at;result;execution;inserted_at;Info;System\r
               #{impl.implementation_key};#{impl.implementation_type};Executable;#{impl.rule.name};#{impl.rule.df_name};#{impl.rule.goal};#{impl.rule.minimum};#{impl.current_business_concept_version.name};#{impl.execution_result_info.date};#{impl.execution_result_info.result};Under Goal;#{impl.inserted_at};field_value;system, system1\r
               """
    end

    test "to_csv/1 manages the download of uninformed result fields" do
      content_labels = %{
        "quality_result.under_goal" => "Under Goal",
        "executable.false" => "Internal",
        "executable.true" => "Executable"
      }

      header_labels = %{"template" => "Template Label", "executable" => "Executable"}

      impl = %{
        implementation_key: "foo",
        implementation_type: "bar",
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
          name: "Rule",
          goal: "12",
          minimum: "8"
        },
        current_business_concept_version: %{
          name: "name"
        },
        execution_result_info: nil,
        inserted_at: "2020-05-05"
      }

      impl1 = %{
        implementation_key: "baz",
        implementation_type: "xyz",
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
          name: "Rule",
          goal: "12",
          minimum: "8"
        },
        current_business_concept_version: %{
          name: "name"
        },
        execution_result_info: %{
          date: "2021-05-05",
          result: "40.00"
        },
        inserted_at: "2021-05-05"
      }

      csv = Download.to_csv([impl, impl1], header_labels, content_labels)

      assert csv ==
               """
               implementation_key;implementation_type;Executable;rule;Template Label;goal;minimum;business_concept;last_execution_at;result;execution;inserted_at;Info;System\r
               #{impl.implementation_key};#{impl.implementation_type};Executable;#{impl.rule.name};#{impl.rule.df_name};#{impl.rule.goal};#{impl.rule.minimum};#{impl.current_business_concept_version.name};;;;#{impl.inserted_at};field_value;system, system1\r
               #{impl1.implementation_key};#{impl1.implementation_type};Internal;#{impl1.rule.name};#{impl1.rule.df_name};#{impl1.rule.goal};#{impl1.rule.minimum};#{impl1.current_business_concept_version.name};#{impl1.execution_result_info.date};#{impl1.execution_result_info.result};;#{impl1.inserted_at};field_value;system, system1\r
               """
    end
  end
end
