defmodule TdDq.Rules.Search.QueryTest do
  use ExUnit.Case

  import TdDd.TestOperators

  alias TdDq.Rules.Search.Query

  describe "Query.build_filters/1" do
    test "returns a match_none clause if no permissions are present" do
      assert Query.build_filters(%{}) == [%{match_none: %{}}]
    end

    test "returns a match_all clause if user has permissions on all domains" do
      permissions = %{
        "manage_confidential_business_concepts" => :all,
        "view_quality_rule" => :all
      }

      assert Query.build_filters(permissions)
             ||| [
               %{match_all: %{}},
               %{
                 must_not: [
                   %{
                     bool: %{
                       filter: [
                         %{term: %{"status" => "draft"}},
                         %{term: %{"implementation_type" => "raw"}}
                       ]
                     }
                   }
                 ]
               },
               %{
                 must_not: [
                   %{
                     bool: %{
                       filter: [
                         %{term: %{"status" => "draft"}},
                         %{term: %{"implementation_type" => "default"}}
                       ]
                     }
                   }
                 ]
               }
             ]
    end

    test "includes a terms clause on the domain_ids field" do
      permissions = %{
        "manage_confidential_business_concepts" => :all,
        "view_quality_rule" => [1, 2]
      }

      assert Query.build_filters(permissions)
             ||| [
               %{terms: %{"domain_ids" => [1, 2]}},
               %{
                 must_not: [
                   %{
                     bool: %{
                       filter: [
                         %{term: %{"status" => "draft"}},
                         %{term: %{"implementation_type" => "raw"}}
                       ]
                     }
                   }
                 ]
               },
               %{
                 must_not: [
                   %{
                     bool: %{
                       filter: [
                         %{term: %{"status" => "draft"}},
                         %{term: %{"implementation_type" => "default"}}
                       ]
                     }
                   }
                 ]
               }
             ]
    end

    test "includes a term clause on the confidential field" do
      permissions = %{
        "view_quality_rule" => [1, 2]
      }

      assert Query.build_filters(permissions)
             ||| [
               %{terms: %{"domain_ids" => [1, 2]}},
               %{term: %{"_confidential" => false}},
               %{
                 must_not: [
                   %{
                     bool: %{
                       filter: [
                         %{term: %{"status" => "draft"}},
                         %{term: %{"implementation_type" => "raw"}}
                       ]
                     }
                   }
                 ]
               },
               %{
                 must_not: [
                   %{
                     bool: %{
                       filter: [
                         %{term: %{"status" => "draft"}},
                         %{term: %{"implementation_type" => "default"}}
                       ]
                     }
                   }
                 ]
               }
             ]
    end

    test "includes a boolean should clause on confidential or domain_ids" do
      permissions = %{
        "manage_confidential_business_concepts" => [4, 5],
        "view_quality_rule" => :all
      }

      assert Query.build_filters(permissions)
             ||| [
               %{match_all: %{}},
               %{
                 bool: %{
                   should: [
                     %{terms: %{"domain_ids" => [4, 5]}},
                     %{term: %{"_confidential" => false}}
                   ]
                 }
               },
               %{
                 must_not: [
                   %{
                     bool: %{
                       filter: [
                         %{term: %{"status" => "draft"}},
                         %{term: %{"implementation_type" => "raw"}}
                       ]
                     }
                   }
                 ]
               },
               %{
                 must_not: [
                   %{
                     bool: %{
                       filter: [
                         %{term: %{"status" => "draft"}},
                         %{term: %{"implementation_type" => "default"}}
                       ]
                     }
                   }
                 ]
               }
             ]
    end

    test "includes a term clause on executable permission scope" do
      permissions = %{
        "manage_confidential_business_concepts" => :all,
        "view_quality_rule" => [1, 2],
        "execute_quality_rule_implementations" => [3]
      }

      assert Query.build_filters(permissions)
             ||| [
               %{terms: %{"domain_ids" => [1, 2]}},
               %{term: %{"executable" => true}},
               %{term: %{"domain_ids" => 3}},
               %{
                 must_not: [
                   %{
                     bool: %{
                       filter: [
                         %{term: %{"status" => "draft"}},
                         %{term: %{"implementation_type" => "raw"}}
                       ]
                     }
                   }
                 ]
               },
               %{
                 must_not: [
                   %{
                     bool: %{
                       filter: [
                         %{term: %{"status" => "draft"}},
                         %{term: %{"implementation_type" => "default"}}
                       ]
                     }
                   }
                 ]
               }
             ]
    end

    # mqri -> manage_quality_rule_implementations
    # mrqri -> manage_raw_quality_rule_implementations
    test "includes a must_not clause with mqri none mrqri none" do
      permissions = %{
        "view_quality_rule" => :all,
        "manage_quality_rule_implementations" => :none,
        "manage_raw_quality_rule_implementations" => :none
      }

      assert Query.build_filters(permissions)
             ||| [
               %{match_all: %{}},
               %{term: %{"_confidential" => false}},
               %{
                 must_not: [
                   %{
                     bool: %{
                       filter: [
                         %{term: %{"status" => "draft"}},
                         %{term: %{"implementation_type" => "raw"}}
                       ]
                     }
                   }
                 ]
               },
               %{
                 must_not: [
                   %{
                     bool: %{
                       filter: [
                         %{term: %{"status" => "draft"}},
                         %{term: %{"implementation_type" => "default"}}
                       ]
                     }
                   }
                 ]
               }
             ]
    end

    # mqri -> manage_quality_rule_implementations
    # mrqri -> manage_raw_quality_rule_implementations
    test "includes a must_not clause with mqri not none mrqri none" do
      permissions = %{
        "view_quality_rule" => :all,
        "manage_quality_rule_implementations" => [1],
        "manage_raw_quality_rule_implementations" => :none
      }

      assert Query.build_filters(permissions)
             ||| [
               %{match_all: %{}},
               %{term: %{"_confidential" => false}},
               %{
                 must_not: [
                   %{
                     bool: %{
                       filter: [
                         %{term: %{"status" => "draft"}},
                         %{term: %{"implementation_type" => "raw"}}
                       ]
                     }
                   }
                 ]
               }
             ]
    end

    # mqri -> manage_quality_rule_implementations
    # mrqri -> manage_raw_quality_rule_implementations
    test "includes a must_not clause with mqri none mrqri not none" do
      permissions = %{
        "view_quality_rule" => :all,
        "manage_quality_rule_implementations" => :none,
        "manage_raw_quality_rule_implementations" => [1]
      }

      assert Query.build_filters(permissions)
             ||| [
               %{match_all: %{}},
               %{term: %{"_confidential" => false}},
               %{
                 must_not: [
                   %{
                     bool: %{
                       filter: [
                         %{term: %{"status" => "draft"}},
                         %{term: %{"implementation_type" => "default"}}
                       ]
                     }
                   }
                 ]
               }
             ]
    end

    # mqri -> manage_quality_rule_implementations
    # mrqri -> manage_raw_quality_rule_implementations
    test "not includes a must_not clause with mqri not none mrqri not none" do
      permissions = %{
        "view_quality_rule" => [1],
        "manage_quality_rule_implementations" => [1],
        "manage_raw_quality_rule_implementations" => [1]
      }

      assert Query.build_filters(permissions)
             ||| [
               %{term: %{"_confidential" => false}},
               %{term: %{"domain_ids" => 1}}
             ]
    end
  end
end
