defmodule Truedat.Search.FiltersTest do
  use ExUnit.Case

  alias Truedat.Search.Filters

  describe "build_filters/3" do
    test "creates filter clauses matching aggregations" do
      filters = %{
        "foo" => "foo",
        "bar" => ["bar1", "bar2"],
        "baz" => ["baz"]
      }

      aggs = %{
        "foo" => %{terms: %{field: "foo_field"}},
        "bar" => %{
          nested: %{path: "content.bar"},
          aggs: %{distinct_search: %{terms: %{field: "content.bar.xyzzy"}}}
        }
      }

      assert filters
             |> Enum.sort()
             |> Filters.build_filters(aggs, %{filter: %{wtf: %{}}}) == %{
               filter: [
                 %{term: %{"foo_field" => "foo"}},
                 %{term: %{"baz" => "baz"}},
                 %{
                   nested: %{
                     path: "content.bar",
                     query: %{terms: %{"content.bar.xyzzy" => ["bar1", "bar2"]}}
                   }
                 },
                 %{wtf: %{}}
               ]
             }
    end

    test "handles updated_at, start_date and end_date as ranges" do
      for field <- ["updated_at", "start_date", "end_date"] do
        assert Filters.build_filters(%{field => %{"gte" => "now-1d/d"}}, %{}) ==
                 %{filter: %{range: %{field => %{"gte" => "now-1d/d"}}}}
      end
    end
  end
end
