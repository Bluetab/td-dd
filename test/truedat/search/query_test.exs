defmodule Truedat.Search.QueryTest do
  use ExUnit.Case

  alias Truedat.Search.Query

  @match_all %{match_all: %{}}
  @match_none %{match_none: %{}}
  @aggs %{
    "status" => %{terms: %{field: "status.raw", size: 50}},
    "type" => %{terms: %{field: "type.raw", size: 50}}
  }

  describe "build_query/1" do
    test "returns a boolean query with a match_all filter by default" do
      assert Query.build_query(@match_all, %{}, @aggs) == %{bool: %{filter: @match_all}}
    end

    test "returns a boolean query with user-defined filters" do
      params = %{"filters" => %{"type" => ["foo"]}}

      assert Query.build_query(@match_all, params, @aggs) == %{
               bool: %{
                 filter: %{term: %{"type.raw" => "foo"}}
               }
             }

      params = %{"filters" => %{"type" => ["foo"], "status" => ["bar", "baz"]}}

      assert Query.build_query(@match_all, params, @aggs) == %{
               bool: %{
                 filter: [
                   %{term: %{"type.raw" => "foo"}},
                   %{terms: %{"status.raw" => ["bar", "baz"]}}
                 ]
               }
             }
    end

    test "returns a simple_query_string for the search term" do
      params = %{"query" => "foo"}

      assert Query.build_query(@match_all, params, @aggs) == %{
               bool: %{
                 filter: %{match_all: %{}},
                 must: %{simple_query_string: %{query: "foo*"}}
               }
             }
    end

    test "returns a boolean query with user-defined filters and simple_query_string" do
      params = %{
        "filters" => %{"type" => ["foo"]},
        "query" => "foo"
      }

      assert Query.build_query(@match_all, params, @aggs) == %{
               bool: %{
                 filter: %{term: %{"type.raw" => "foo"}},
                 must: %{simple_query_string: %{query: "foo*"}}
               }
             }
    end

    test "with and without clauses" do
      params = %{
        "with" => ["foo", "bar"],
        "without" => "baz"
      }

      assert Query.build_query(@match_none, params) == %{
               bool: %{
                 filter: [%{exists: %{field: "bar"}}, %{exists: %{field: "foo"}}, @match_none],
                 must_not: %{exists: %{field: "baz"}}
               }
             }
    end

    test "returns a query with must_not filters" do
      filters = %{
        must_not: [%{term: %{"foo" => "bar"}}]
      }

      params = %{}

      assert Query.build_query(filters, params) == %{
               bool: %{
                 must_not: %{term: %{"foo" => "bar"}}
               }
             }
    end

    test "returns a query with must_not params" do
      filters = %{}

      params = %{
        "filters" => %{"must_not" => %{"foo" => ["bar"]}}
      }

      assert Query.build_query(filters, params) == %{
               bool: %{
                 filter: %{},
                 must_not: %{term: %{"foo" => "bar"}}
               }
             }
    end

    test "returns a query with must_not params and filter" do
      filters = %{
        must_not: [%{term: %{"foo" => "bar"}}]
      }

      params = %{
        "filters" => %{"must_not" => %{"baz" => ["xyz"]}}
      }

      assert Query.build_query(filters, params) == %{
               bool: %{
                 must_not: [
                   %{term: %{"baz" => "xyz"}},
                   %{term: %{"foo" => "bar"}}
                 ]
               }
             }
    end
  end
end
