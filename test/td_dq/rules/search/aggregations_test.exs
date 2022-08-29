defmodule TdDq.Rules.Search.AggregationsTest do
  use TdDd.DataCase

  alias TdDq.Rules.Search.Aggregations

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

    CacheHelpers.insert_template(scope: "dq", content: [field_group])
    :ok
  end

  describe "aggregations/0" do
    test "includes static aggregations" do
      assert %{"active.raw" => _, "taxonomy" => _} = Aggregations.aggregations()
    end

    test "includes dynamic content" do
      assert %{
               "active.raw" => _,
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
             } = aggs = Aggregations.aggregations()

      refute Map.has_key?(aggs, "my_string")
    end
  end
end
