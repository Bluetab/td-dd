defmodule TdDq.Implementations.Search.AggregationsTest do
  use TdDd.DataCase

  alias TdCore.Search.ElasticDocumentProtocol
  alias TdDq.Implementations.Implementation

  setup do
    fields = [
      build(:template_field, name: "my_string", type: "string"),
      build(:template_field, name: "my_system", type: "system"),
      build(:template_field, name: "my_domain", type: "domain"),
      build(:template_field,
        name: "my_list",
        type: "list",
        values: %{"fixed" => ["one", "two", "three"]}
      )
    ]

    field_group = build(:template_group, fields: fields)

    CacheHelpers.insert_template(scope: "ri", content: [field_group])
    :ok
  end

  describe "aggregations/0" do
    test "includes static aggregations" do
      assert %{
               "taxonomy" => _,
               "execution_result_info.result_text" => _,
               "result_type.raw" => _,
               "rule" => _,
               "source_external_id" => _,
               "linked_structures_ids" => _
             } = ElasticDocumentProtocol.aggregations(%Implementation{})
    end

    test "includes dynamic content" do
      assert %{
               "my_domain" => %{
                 meta: %{type: "domain"},
                 terms: %{field: "df_content.my_domain", size: 50}
               },
               "my_list" => %{terms: %{field: "df_content.my_list.raw"}},
               "my_system" => %{
                 aggs: %{
                   distinct_search: %{terms: %{field: "df_content.my_system.external_id.raw"}}
                 },
                 nested: %{path: "df_content.my_system"}
               },
               "taxonomy" => _
             } = aggs = ElasticDocumentProtocol.aggregations(%Implementation{})

      refute Map.has_key?(aggs, "my_string")
    end

    test "includes rule content" do
      fields = [
        build(:template_field, name: "my_system", type: "system"),
        build(:template_field, name: "my_rule_domain", type: "domain")
      ]

      field_group = build(:template_group, fields: fields)

      CacheHelpers.insert_template(scope: "dq", content: [field_group])

      assert %{
               "my_domain" => %{
                 meta: %{type: "domain"},
                 terms: %{field: "df_content.my_domain", size: 50}
               },
               "my_list" => %{terms: %{field: "df_content.my_list.raw"}},
               "my_system" => %{
                 aggs: %{
                   distinct_search: %{terms: %{field: "df_content.my_system.external_id.raw"}}
                 },
                 nested: %{path: "df_content.my_system"}
               },
               "taxonomy" => _,
               "my_rule_domain" => %{
                 meta: %{type: "domain"},
                 terms: %{field: "rule.df_content.my_rule_domain", size: 50}
               }
             } = ElasticDocumentProtocol.aggregations(%Implementation{})
    end
  end
end
