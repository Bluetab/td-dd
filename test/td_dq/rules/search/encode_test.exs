defmodule TdDq.Rules.Search.EncodeTest do
  use TdDqWeb.ConnCase

  alias Elasticsearch.Document
  alias TdDfLib.Content

  @df_template %{
    id: System.unique_integer([:positive]),
    label: "df_test",
    name: "df_test",
    scope: "dq",
    content: [
      %{
        "name" => "Content Template",
        "fields" => [
          %{
            "cardinality" => "?",
            "label" => "foo",
            "name" => "foo",
            "subscribable" => false,
            "type" => "string",
            "values" => nil,
            "widget" => "string"
          }
        ]
      }
    ]
  }

  setup do
    %{name: template_name} = CacheHelpers.insert_template(@df_template)

    %{id: concept_id} =
      concept =
      CacheHelpers.insert_concept(
        name: "Concept",
        content: %{
          "baz" => %{"origin" => "user", "value" => "foo"}
        }
      )

    rule =
      insert(:rule,
        df_name: template_name,
        df_content: %{"foo" => %{"origin" => "user", "value" => "bar"}},
        business_concept_id: concept_id
      )

    [rule: rule, concept: concept]
  end

  describe "encode/1" do
    test "the content of rules and concepts should have a format without origin", %{
      rule: %{id: rule_id} = rule,
      concept: concept
    } do
      %{df_content: rule_legacy_content} = Content.legacy_content_support(rule, :df_content)

      %{content: concept_legacy_content} = Content.legacy_content_support(concept, :content)

      assert %{
               id: ^rule_id,
               df_content: rule_content,
               current_business_concept_version: %{content: concept_content}
             } = Document.encode(rule)

      assert concept_legacy_content == concept_content
      assert rule_legacy_content == rule_content
    end
  end
end
