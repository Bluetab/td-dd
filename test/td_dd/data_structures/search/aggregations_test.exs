defmodule TdDd.DataStructures.Search.AggregationsTest do
  use TdDd.DataCase

  alias TdCore.Search.ElasticDocumentProtocol
  alias TdDd.DataStructures.DataStructureVersion

  @default_size 500
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
      aggs = ElasticDocumentProtocol.aggregations(%DataStructureVersion{})

      for field <- @static_fields do
        assert Map.has_key?(aggs, field)
      end
    end

    test "includes dynamic aggregations" do
      dynamic_aggs =
        ElasticDocumentProtocol.aggregations(%DataStructureVersion{}) |> Map.drop(@static_fields)

      assert dynamic_aggs == %{
               "my_domain" => %{
                 meta: %{type: "domain"},
                 terms: %{field: "note.my_domain", size: @default_size}
               },
               "my_list" => %{terms: %{field: "note.my_list.raw", size: @default_size}},
               "my_system" => %{
                 aggs: %{
                   distinct_search: %{
                     terms: %{field: "note.my_system.external_id.raw", size: @default_size}
                   }
                 },
                 nested: %{path: "note.my_system"}
               },
               "my_user" => %{terms: %{field: "note.my_user.raw", size: @default_size}}
             }
    end

    test "includes metadata field aggregations" do
      insert(:data_structure_type, filters: ["foo"])
      insert(:data_structure_type, filters: ["bar", "baz"])

      aggs = ElasticDocumentProtocol.aggregations(%DataStructureVersion{})

      assert_maps_equal(
        aggs,
        %{
          "metadata.bar" => %{terms: %{field: "_filters.bar", size: @default_size}},
          "metadata.baz" => %{terms: %{field: "_filters.baz", size: @default_size}},
          "metadata.foo" => %{terms: %{field: "_filters.foo", size: @default_size}}
        },
        ["metadata.foo", "metadata.bar", "metadata.baz"]
      )
    end

    test "includes custom catalog view configs field aggregations" do
      insert(:data_structure_type, filters: ["host"])
      insert(:catalog_view_config, field_type: "metadata", field_name: "host")
      insert(:catalog_view_config, field_type: "note", field_name: "layer")

      %{
        "metadata.host" => %{
          terms: %{field: "_filters.host"}
        },
        "note.layer" => %{terms: %{field: "note.layer.raw"}}
      } = ElasticDocumentProtocol.aggregations(%DataStructureVersion{})
    end
  end
end
