defmodule TdDd.DataStructures.Search.AggregationsTest do
  use TdDd.DataCase

  alias TdDd.DataStructures.Search.Aggregations

  @static_fields [
    "class.raw",
    "confidential.raw",
    "field_type.raw",
    "group.raw",
    "linked_concepts",
    "system.name.raw",
    "tags.raw",
    "taxonomy",
    "type.raw",
    "with_content.raw",
    "with_profiling.raw"
  ]

  setup do
    fields = [
      build(:template_field, name: "my_string", type: "string"),
      build(:template_field, name: "my_system", type: "system"),
      build(:template_field, name: "my_domain", type: "domain"),
      build(:template_field, name: "my_user", type: "user"),
      build(:template_field,
        name: "my_list",
        type: "list",
        values: %{"fixed" => ["one", "two", "three"]}
      )
    ]

    field_group = build(:template_group, fields: fields)

    CacheHelpers.insert_template(scope: "dd", content: [field_group])
    :ok
  end

  describe "aggregations/0" do
    test "includes static aggregations" do
      aggs = Aggregations.aggregations()

      for field <- @static_fields do
        assert Map.has_key?(aggs, field)
      end
    end

    test "includes dynamic aggregations" do
      dynamic_aggs = Aggregations.aggregations() |> Map.drop(@static_fields)

      assert dynamic_aggs == %{
               "my_domain" => %{
                 aggs: %{
                   distinct_search: %{terms: %{field: "latest_note.my_domain.external_id.raw"}}
                 },
                 nested: %{path: "latest_note.my_domain"}
               },
               "my_list" => %{terms: %{field: "latest_note.my_list.raw"}},
               "my_system" => %{
                 aggs: %{
                   distinct_search: %{terms: %{field: "latest_note.my_system.external_id.raw"}}
                 },
                 nested: %{path: "latest_note.my_system"}
               },
               "my_user" => %{terms: %{field: "latest_note.my_user.raw", size: 50}}
             }
    end
  end
end
