defmodule TdDq.Implementations.Search.EncodeTest do
  use TdDqWeb.ConnCase

  alias Elasticsearch.Document
  alias TdDd.Repo
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
    %{name: rule_template_name} = CacheHelpers.insert_template(@df_template)

    %{name: impl_template_name} =
      @df_template
      |> Map.put(:scope, "ri")
      |> CacheHelpers.insert_template()

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
        df_name: rule_template_name,
        df_content: %{"foo" => %{"origin" => "user", "value" => "bar"}},
        business_concept_id: concept_id
      )

    implementation =
      :implementation
      |> insert(
        rule: rule,
        df_name: impl_template_name,
        df_content: %{"foo" => %{"origin" => "user", "value" => "zaz"}}
      )
      |> Repo.preload([:rule, :implementation_ref_struct])

    [rule: rule, concept: concept, implementation: implementation]
  end

  describe "encode/1" do
    test "the content of implementations, rules and concepts should have a format without origin",
         %{
           rule: rule,
           implementation: %{id: impl_id} = implementation,
           concept: concept
         } do
      %{df_content: rule_legacy_content} = Content.legacy_content_support(rule, :df_content)

      %{df_content: impl_legacy_content} =
        Content.legacy_content_support(implementation, :df_content)

      %{content: concept_legacy_content} = Content.legacy_content_support(concept, :content)

      assert %{
               id: ^impl_id,
               df_content: impl_content,
               current_business_concept_version: %{content: concept_content},
               rule: %{df_content: rule_content}
             } = Document.encode(implementation)

      assert concept_legacy_content == concept_content
      assert rule_legacy_content == rule_content
      assert impl_legacy_content == impl_content
    end
  end
end
