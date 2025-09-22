defmodule TdDq.Implementations.Search.ElasticDocumentTest do
  use TdDqWeb.ConnCase

  alias Elasticsearch.Document
  alias TdCore.Search.ElasticDocumentProtocol
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

  describe "mappings/1" do
    test "returns mappings for a standalone implementation without rule" do
      implementation = insert(:ruleless_implementation)

      mappings = ElasticDocumentProtocol.mappings(implementation)

      assert %{mappings: %{properties: properties}, settings: _settings} = mappings

      assert %{id: %{type: "long"}} = properties
      assert %{business_concept_id: %{type: "text"}} = properties
      assert %{implementation_key: %{type: "text", fields: _}} = properties
      assert %{implementation_type: %{type: "text", fields: _}} = properties

      assert %{rule: %{properties: rule_properties}} = properties
      assert %{df_name: %{type: "text", fields: _}} = rule_properties
      assert %{df_content: %{properties: _}} = rule_properties
    end

    test "returns mappings for implementation related to a rule only" do
      rule_template = %{
        id: System.unique_integer([:positive]),
        label: "rule_test",
        name: "rule_test",
        scope: "dq",
        content: [
          %{
            "name" => "Rule Template",
            "fields" => [
              %{
                "cardinality" => "?",
                "label" => "rule_field",
                "name" => "rule_field",
                "subscribable" => false,
                "type" => "string",
                "values" => nil,
                "widget" => "string"
              }
            ]
          }
        ]
      }

      %{name: rule_template_name} = CacheHelpers.insert_template(rule_template)

      impl_template = %{
        id: System.unique_integer([:positive]),
        label: "impl_test",
        name: "impl_test",
        scope: "ri",
        content: [
          %{
            "name" => "Implementation Template",
            "fields" => [
              %{
                "cardinality" => "?",
                "label" => "impl_field",
                "name" => "impl_field",
                "subscribable" => false,
                "type" => "string",
                "values" => nil,
                "widget" => "string"
              }
            ]
          }
        ]
      }

      %{name: impl_template_name} = CacheHelpers.insert_template(impl_template)

      rule = insert(:rule, df_name: rule_template_name)

      implementation =
        insert(:implementation,
          rule: rule,
          df_name: impl_template_name
        )

      mappings = ElasticDocumentProtocol.mappings(implementation)

      assert %{mappings: %{properties: properties}, settings: _settings} = mappings

      assert %{rule: %{properties: rule_properties}} = properties
      assert %{df_name: %{type: "text", fields: _}} = rule_properties
      assert %{df_content: %{properties: rule_content_mappings}} = rule_properties

      assert Map.has_key?(rule_content_mappings, "rule_field")
    end

    test "returns mappings for implementation related to rule with concept containing user field" do
      concept_template = %{
        id: System.unique_integer([:positive]),
        label: "concept_test",
        name: "concept_test",
        scope: "bg",
        content: [
          %{
            "name" => "Concept Template",
            "fields" => [
              %{
                "cardinality" => "?",
                "label" => "concept_user_field",
                "name" => "concept_user_field",
                "subscribable" => false,
                "type" => "user",
                "values" => nil,
                "widget" => "user"
              }
            ]
          }
        ]
      }

      %{name: _concept_template_name} = CacheHelpers.insert_template(concept_template)

      rule_template = %{
        id: System.unique_integer([:positive]),
        label: "rule_test",
        name: "rule_test",
        scope: "dq",
        content: [
          %{
            "name" => "Rule Template",
            "fields" => [
              %{
                "cardinality" => "?",
                "label" => "rule_field",
                "name" => "rule_field",
                "subscribable" => false,
                "type" => "string",
                "values" => nil,
                "widget" => "string"
              }
            ]
          }
        ]
      }

      %{name: rule_template_name} = CacheHelpers.insert_template(rule_template)

      impl_template = %{
        id: System.unique_integer([:positive]),
        label: "impl_test",
        name: "impl_test",
        scope: "ri",
        content: [
          %{
            "name" => "Implementation Template",
            "fields" => [
              %{
                "cardinality" => "?",
                "label" => "impl_field",
                "name" => "impl_field",
                "subscribable" => false,
                "type" => "string",
                "values" => nil,
                "widget" => "string"
              }
            ]
          }
        ]
      }

      %{name: impl_template_name} = CacheHelpers.insert_template(impl_template)

      concept =
        CacheHelpers.insert_concept(
          name: "Test Concept",
          content: %{
            "concept_user_field" => %{"origin" => "user", "value" => "test_user"}
          }
        )

      rule =
        insert(:rule,
          df_name: rule_template_name,
          business_concept_id: concept.id
        )

      implementation =
        insert(:implementation,
          rule: rule,
          df_name: impl_template_name
        )

      mappings = ElasticDocumentProtocol.mappings(implementation)

      assert %{mappings: %{properties: properties}, settings: _settings} = mappings

      assert %{current_business_concept_version: %{properties: concept_properties}} = properties
      assert %{content: %{properties: concept_content_mappings}} = concept_properties

      assert Map.has_key?(concept_content_mappings, "concept_user_field")
    end

    test "returns mappings for implementation related to rule with concept containing string, user, and user_group fields" do
      concept_template = %{
        id: System.unique_integer([:positive]),
        label: "concept_test",
        name: "concept_test",
        scope: "bg",
        content: [
          %{
            "name" => "Concept Template",
            "fields" => [
              %{
                "cardinality" => "?",
                "label" => "string_field",
                "name" => "string_field",
                "subscribable" => false,
                "type" => "string",
                "values" => nil,
                "widget" => "string"
              },
              %{
                "cardinality" => "?",
                "label" => "user_field",
                "name" => "user_field",
                "subscribable" => false,
                "type" => "user",
                "values" => nil,
                "widget" => "user"
              },
              %{
                "cardinality" => "?",
                "label" => "user_group_field",
                "name" => "user_group_field",
                "subscribable" => false,
                "type" => "user_group",
                "values" => nil,
                "widget" => "user_group"
              }
            ]
          }
        ]
      }

      %{name: _concept_template_name} = CacheHelpers.insert_template(concept_template)

      rule_template = %{
        id: System.unique_integer([:positive]),
        label: "rule_test",
        name: "rule_test",
        scope: "dq",
        content: [
          %{
            "name" => "Rule Template",
            "fields" => [
              %{
                "cardinality" => "?",
                "label" => "rule_field",
                "name" => "rule_field",
                "subscribable" => false,
                "type" => "string",
                "values" => nil,
                "widget" => "string"
              }
            ]
          }
        ]
      }

      %{name: rule_template_name} = CacheHelpers.insert_template(rule_template)

      impl_template = %{
        id: System.unique_integer([:positive]),
        label: "impl_test",
        name: "impl_test",
        scope: "ri",
        content: [
          %{
            "name" => "Implementation Template",
            "fields" => [
              %{
                "cardinality" => "?",
                "label" => "impl_field",
                "name" => "impl_field",
                "subscribable" => false,
                "type" => "string",
                "values" => nil,
                "widget" => "string"
              }
            ]
          }
        ]
      }

      %{name: impl_template_name} = CacheHelpers.insert_template(impl_template)

      concept =
        CacheHelpers.insert_concept(
          name: "Test Concept",
          content: %{
            "string_field" => %{"origin" => "user", "value" => "test_string"},
            "user_field" => %{"origin" => "user", "value" => "test_user"},
            "user_group_field" => %{"origin" => "user", "value" => "test_group"}
          }
        )

      rule =
        insert(:rule,
          df_name: rule_template_name,
          business_concept_id: concept.id
        )

      implementation =
        insert(:implementation,
          rule: rule,
          df_name: impl_template_name
        )

      mappings = ElasticDocumentProtocol.mappings(implementation)

      assert %{mappings: %{properties: properties}, settings: _settings} = mappings

      assert %{current_business_concept_version: %{properties: concept_properties}} = properties
      assert %{content: %{properties: concept_content_mappings}} = concept_properties

      assert Map.has_key?(concept_content_mappings, "user_field")
      assert Map.has_key?(concept_content_mappings, "user_group_field")

      refute Map.has_key?(concept_content_mappings, "string_field")
    end
  end
end
