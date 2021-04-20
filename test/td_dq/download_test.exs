defmodule TdDq.DownloadTest do
  @moduledoc """
  Tests download of implementations in csv format
  """
  use TdDd.DataCase

  alias TdCache.TemplateCache
  alias TdDq.Rules.Implementations.Download

  defp create_template(_) do
    template = %{
      id: :rand.uniform(100_000_000),
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
    setup [:create_template]

    test "download empty csv" do
      csv = Download.to_csv([], %{}, %{})
      assert csv == ""
    end

    test "to_csv/1 return csv content to download" do
      content_labels = %{"quality_result.under_goal" => "Under Goal"}
      header_labels = %{"template" => "Template Label"}

      impl = %{
        implementation_key: "key1",
        implementation_type: "type1",
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
               implementation_key;implementation_type;rule;Template Label;goal;minimum;business_concept;last_execution_at;result;execution;inserted_at;Info;System\r
               #{impl.implementation_key};#{impl.implementation_type};#{impl.rule.name};#{
                 impl.rule.df_name
               };#{impl.rule.goal};#{impl.rule.minimum};#{
                 impl.current_business_concept_version.name
               };#{impl.execution_result_info.date};#{impl.execution_result_info.result};Under Goal;#{
                 impl.inserted_at
               };field_value;system, system1\r
               """
    end
  end
end
