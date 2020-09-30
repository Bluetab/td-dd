defmodule TdDq.Search.AggregationsTest do
  use TdDq.DataCase
  alias TdCache.TemplateCache
  alias TdDq.Search.Aggregations

  def create_template(template) do
    template
    |> Map.put(:updated_at, DateTime.utc_now())
    |> TemplateCache.put()

    template
  end

  describe "aggregation_terms" do
    test "aggregation_terms/0 returns aggregation terms of type user with size 50" do
      template_content = [
        %{
          "name" => "group",
          "fields" => [
            %{name: "fieldname", type: "string", cardinality: "?", values: %{}},
            %{name: "userfield", type: "user", cardinality: "?", values: %{}}
          ]
        }
      ]

      create_template(%{
        id: 0,
        name: "onefield",
        content: template_content,
        label: "label",
        scope: "dq"
      })

      aggs = Aggregations.rule_aggregation_terms()

      %{field: field, size: size} =
        aggs
        |> Map.get("userfield")
        |> Map.get(:terms)
        |> Map.take([:field, :size])

      assert size == 50
      assert field == "df_content.userfield.raw"
    end
  end
end
