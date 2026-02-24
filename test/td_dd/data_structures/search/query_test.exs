defmodule TdDd.DataStructures.Search.QueryTest do
  use ExUnit.Case

  alias TdDd.DataStructures.Search.Query

  @all_permissions %{"view_data_structure" => :all, "manage_confidential_structures" => :all}
  @match_all %{match_all: %{}}
  @match_none %{match_none: %{}}
  @not_confidential %{term: %{"confidential" => false}}

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

    test "returns bool query for domain_ids or confidential domain_ids with field prefix" do
      opts = [field_prefix: "foo."]

      assert Query.build_filters(
               %{"view_data_structure" => [1], "manage_confidential_structures" => [2]},
               opts
             ) ==
               %{
                 bool: %{
                   should: [
                     %{
                       bool: %{
                         filter: [
                           %{term: %{"foo.domain_ids" => 1}},
                           %{term: %{"foo.confidential" => false}}
                         ]
                       }
                     },
                     %{bool: %{filter: %{term: %{"foo.domain_ids" => 2}}}}
                   ]
                 }
               }

      assert Query.build_filters(
               %{"link_data_structure" => [1, 2], "manage_confidential_structures" => [2, 3]},
               opts
             ) ==
               %{
                 bool: %{
                   should: [
                     %{
                       bool: %{
                         filter: [
                           %{terms: %{"foo.domain_ids" => [1, 2]}},
                           %{term: %{"foo.confidential" => false}}
                         ]
                       }
                     },
                     %{bool: %{filter: %{terms: %{"foo.domain_ids" => [2, 3]}}}}
                   ]
                 }
               }
    end
  end

  describe "build_query/3" do
    test "includes a must multi_match clause for a single word" do
      assert %{
               bool: %{
                 filter: %{match_all: %{}},
                 should: [
                   %{
                     multi_match: %{
                       type: "phrase_prefix",
                       fields: [],
                       query: " foo     ",
                       boost: 4.0,
                       lenient: true
                     }
                   },
                   %{
                     simple_query_string: %{
                       fields: [],
                       query: " foo     ",
                       boost: 4.0,
                       quote_field_suffix: ".exact"
                     }
                   }
                 ],
                 must: %{
                   multi_match: %{
                     type: "bool_prefix",
                     fields: [],
                     query: " foo     ",
                     lenient: true
                   }
                 }
               }
             } ==
               Query.build_query(@all_permissions, %{"query" => " foo     "}, %{
                 query: %{
                   as_you_type: [],
                   simple: [],
                   exact: []
                 }
               })
    end

    test "includes a must exists and multi_match clause for a single word" do
      assert %{
               bool: %{
                 must: %{
                   multi_match: %{
                     fields: [],
                     lenient: true,
                     query: "foo",
                     type: "bool_prefix"
                   }
                 },
                 filter: %{exists: %{"field" => "foo.moo"}},
                 should: [
                   %{
                     multi_match: %{
                       type: "phrase_prefix",
                       fields: [],
                       query: "foo",
                       boost: 4.0,
                       lenient: true
                     }
                   },
                   %{
                     simple_query_string: %{
                       fields: [],
                       query: "\"foo\"",
                       boost: 4.0,
                       quote_field_suffix: ".exact"
                     }
                   }
                 ]
               }
             } ==
               Query.build_query(
                 @all_permissions,
                 %{"query" => "foo", "must" => %{"exists" => %{"field" => "foo.moo"}}},
                 %{query: %{as_you_type: [], simple: [], exact: []}}
               )
    end

    test "includes a multi_match clause for each word in the query term" do
      assert %{
               bool: %{
                 filter: %{match_all: %{}},
                 should: [
                   %{
                     multi_match: %{
                       type: "phrase_prefix",
                       fields: [],
                       query: " foo   bar  ",
                       boost: 4.0,
                       lenient: true
                     }
                   },
                   %{
                     simple_query_string: %{
                       fields: [],
                       query: " foo   bar  ",
                       boost: 4.0,
                       quote_field_suffix: ".exact"
                     }
                   }
                 ],
                 must: %{
                   multi_match: %{
                     type: "bool_prefix",
                     fields: [],
                     query: " foo   bar  ",
                     lenient: true
                   }
                 }
               }
             } ==
               Query.build_query(@all_permissions, %{"query" => " foo   bar  "}, %{
                 query: %{
                   as_you_type: [],
                   simple: [],
                   exact: []
                 }
               })
    end

    test "does not include a must clause for an empty search term" do
      assert Query.build_query(@all_permissions, %{"query" => "  "}, %{}) == %{
               bool: %{must: %{simple_query_string: %{query: "  "}}, filter: %{match_all: %{}}}
             }
    end

    test "includes simple query string search when wildcard is provided" do
      assert Query.build_query(@all_permissions, %{"query" => "\"foo\""}, %{
               query: %{
                 simple: [],
                 as_you_type: [],
                 exact: []
               }
             }) == %{
               bool: %{
                 must: %{
                   simple_query_string: %{
                     fields: [],
                     query: "\"foo\"",
                     quote_field_suffix: ".exact"
                   }
                 },
                 filter: %{match_all: %{}}
               }
             }
    end
  end

  describe "custom search fields" do
    test "includes multi_match with custom fields" do
      assert %{
               bool: %{
                 filter: %{
                   bool: %{
                     should: [
                       %{term: %{"data_structure_id" => "214265"}},
                       %{term: %{"parent_id" => "214265"}}
                     ],
                     minimum_should_match: 1
                   }
                 }
               }
             } ==
               Query.build_query(
                 @all_permissions,
                 %{
                   "filters" => %{
                     "should" => %{"data_structure_id" => ["214265"], "parent_id" => ["214265"]}
                   }
                 },
                 %{
                   query: %{
                     simple: [],
                     as_you_type: []
                   }
                 }
               )
    end

    test "maintains backward compatibility for wildcard queries without search_fields" do
      assert %{
               bool: %{
                 must: %{
                   simple_query_string: %{
                     fields: ["default_field1", "default_field2"],
                     query: "\"test\"",
                     quote_field_suffix: ".exact"
                   }
                 },
                 filter: %{match_all: %{}}
               }
             } ==
               Query.build_query(@all_permissions, %{"query" => "\"test\""}, %{
                 query: %{
                   as_you_type: ["default_field1", "default_field2"],
                   simple: ["default_field1", "default_field2"],
                   exact: ["default_field1", "default_field2"]
                 }
               })
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
