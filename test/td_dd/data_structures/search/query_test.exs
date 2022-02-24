defmodule TdDd.DataStructures.Search.QueryTest do
  use ExUnit.Case

  alias TdDd.DataStructures.Search.Query

  @permissions ["view_data_structure", "link_data_structure"]

  describe "build_filters/1" do
    test "returns match_all query if permission scope is all" do
      for permission <- @permissions do
        assert Query.build_filters(%{permission => :all}) == %{match_all: %{}}
      end
    end

    test "returns match_none query if permission scope is all" do
      for permission <- @permissions do
        assert Query.build_filters(%{permission => :none}) == %{match_none: %{}}
      end
    end

    test "returns term if permission scope is a single integer" do
      for permission <- @permissions do
        assert Query.build_filters(%{permission => [1]}) == %{term: %{"domain_id" => 1}}
      end
    end

    test "returns term if permission scope is a list of integers" do
      for permission <- @permissions do
        assert Query.build_filters(%{permission => [1, 2]}) == %{terms: %{"domain_id" => [1, 2]}}
      end
    end
  end
end
