defmodule TdDd.DataStructures.Search.QueryTest do
  use ExUnit.Case

  alias TdDd.DataStructures.Search.Query

  @all_permissions %{"view_data_structure" => :all, "manage_confidential_structures" => :all}
  @match_all %{match_all: %{}}
  @match_none %{match_none: %{}}
  @not_confidential %{term: %{"confidential" => false}}

  setup_all do
    :ok
  end

  describe "build_filters/1" do
    test "returns match_all query if view scope and confidential scope are all" do
      assert build_view_filters(:all, :all) == @match_all
      assert build_link_filters(:all, :all) == @match_all
    end

    test "returns match_none query if view scope is all" do
      assert build_view_filters(:none, :foo) == @match_none
      assert build_link_filters(:none, :bar) == @match_none
    end

    test "returns term query on confidential if confidential scope is none" do
      assert build_view_filters(:all, :none) == @not_confidential
      assert build_link_filters(:all, :none) == @not_confidential
    end

    test "returns filters for domain_ids and not confidential" do
      assert build_view_filters([1], :none) ==
               [%{term: %{"domain_ids" => 1}}, @not_confidential]

      assert build_link_filters([1, 2], :none) ==
               [%{terms: %{"domain_ids" => [1, 2]}}, @not_confidential]
    end

    test "returns filters for domain_ids if confidential scope is all" do
      assert build_view_filters([1], :all) == %{term: %{"domain_ids" => 1}}
      assert build_link_filters([1, 2], :all) == %{terms: %{"domain_ids" => [1, 2]}}
    end

    test "returns bool query for domain_ids or confidential domain_ids" do
      assert build_view_filters([1], [2]) ==
               %{
                 bool: %{
                   should: [
                     %{
                       bool: %{
                         filter: [
                           %{term: %{"domain_ids" => 1}},
                           @not_confidential
                         ]
                       }
                     },
                     %{bool: %{filter: %{term: %{"domain_ids" => 2}}}}
                   ]
                 }
               }

      assert build_link_filters([1, 2], [2, 3]) ==
               %{
                 bool: %{
                   should: [
                     %{
                       bool: %{
                         filter: [
                           %{terms: %{"domain_ids" => [1, 2]}},
                           @not_confidential
                         ]
                       }
                     },
                     %{bool: %{filter: %{terms: %{"domain_ids" => [2, 3]}}}}
                   ]
                 }
               }
    end
  end

  describe "build_query/3" do
    test "includes a must multi_match clause for a single word" do
      assert %{
               bool: %{
                 must: [%{multi_match: %{query: "foo"}}, @match_all]
               }
             } = Query.build_query(@all_permissions, %{"query" => " foo     "}, %{})
    end

    test "includes a must exists and multi_match clause for a single word" do
      assert %{
               bool: %{
                 must: [
                   %{multi_match: %{fields: _, lenient: _, query: "foo", type: _}},
                   %{exists: %{"field" => "foo.moo"}}
                 ]
               }
             } =
               Query.build_query(
                 @all_permissions,
                 %{"query" => " foo     ", "must" => %{"exists" => %{"field" => "foo.moo"}}},
                 %{}
               )
    end

    test "includes a multi_match clause for each word in the query term" do
      assert %{
               bool: %{
                 must: [
                   %{
                     bool: %{
                       minimum_should_match: "2<-75%",
                       should: [%{multi_match: %{query: "foo"}}, %{multi_match: %{query: "bar"}}]
                     }
                   },
                   %{match_all: %{}}
                 ]
               }
             } = Query.build_query(@all_permissions, %{"query" => " foo   bar  "}, %{})
    end

    test "does not include a must clause for an empty search term" do
      assert Query.build_query(@all_permissions, %{"query" => "  "}, %{}) ==
               %{bool: %{must: @match_all}}
    end
  end

  defp build_view_filters(view_scope, confidential_scope) do
    %{"view_data_structure" => view_scope, "manage_confidential_structures" => confidential_scope}
    |> Query.build_filters()
  end

  defp build_link_filters(view_scope, confidential_scope) do
    %{"link_data_structure" => view_scope, "manage_confidential_structures" => confidential_scope}
    |> Query.build_filters()
  end
end
