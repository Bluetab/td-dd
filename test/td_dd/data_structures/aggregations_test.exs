defmodule TdDd.Search.AggregationsTest do
  use TdDd.DataCase
  alias TdCache.TemplateCache
  alias TdDd.Search.Aggregations

  @static_fields [
    "ou.raw",
    "system.name.raw",
    "group.raw",
    "type.raw",
    "confidential.raw",
    "class.raw",
    "field_type.raw"
  ]
  def create_template(template) do
    template
    |> Map.put(:updated_at, DateTime.utc_now())
    |> TemplateCache.put()

    template
  end

  describe "aggregation_terms" do
    test "aggregation_terms/0 returns aggregation terms of type user with size 50" do
      template_content = [
        %{name: "fieldname", type: "string", cardinality: "?", values: %{}},
        %{name: "userfield", type: "user", cardinality: "?", values: %{}}
      ]

      create_template(%{
        id: 0,
        name: "onefield",
        content: template_content,
        label: "label",
        scope: "dd"
      })

      aggs = Aggregations.aggregation_terms()

      %{field: field, size: size} =
        aggs
        |> Map.get("userfield")
        |> Map.get(:terms)
        |> Map.take([:field, :size])

      assert size == 50
      assert field == "df_content.userfield.raw"
    end

    test "aggregation_terms/0 returns aggregations of static fields" do
      aggs = Aggregations.aggregation_terms() 
      assert Enum.all?(@static_fields, &Map.has_key?(aggs, &1))
    end
  end
end
