defmodule TdDq.Rules.Search.QueryTest do
  use ExUnit.Case

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

      assert Query.build_filters(permissions) == [%{match_all: %{}}]
    end

    test "includes a term clause on the domain_id field" do
      permissions = %{
        "manage_confidential_business_concepts" => :all,
        "view_quality_rule" => [1, 2]
      }

      assert Query.build_filters(permissions) == [%{terms: %{"domain_id" => [1, 2]}}]
    end

    test "includes a term clause on the confidential field" do
      permissions = %{
        "view_quality_rule" => [1, 2]
      }

      assert Query.build_filters(permissions) == [
               %{terms: %{"domain_id" => [1, 2]}},
               %{term: %{"_confidential" => false}}
             ]
    end

    test "includes a boolean should clause on confidential or domain_id" do
      permissions = %{
        "manage_confidential_business_concepts" => [4, 5],
        "view_quality_rule" => :all
      }

      assert Query.build_filters(permissions) == [
               %{match_all: %{}},
               %{
                 bool: %{
                   should: [
                     %{terms: %{"domain_id" => [4, 5]}},
                     %{term: %{"_confidential" => false}}
                   ]
                 }
               }
             ]
    end

    test "includes a term clause on executable permission scope" do
      permissions = %{
        "manage_confidential_business_concepts" => :all,
        "view_quality_rule" => [1, 2],
        "execute_quality_rule_implementations" => [3]
      }

      assert Query.build_filters(permissions) == [
               %{terms: %{"domain_id" => [1, 2]}},
               %{term: %{"domain_id" => 3}}
             ]
    end
  end
end
