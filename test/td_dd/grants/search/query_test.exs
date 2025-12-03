defmodule TdDd.Grants.Search.QueryTest do
  use TdDd.DataCase

  alias TdDd.Grants.Search.Query

  describe "build_query/4" do
    test "builds query with manage_grants and view_grants as :all" do
      permissions = %{"manage_grants" => :all, "view_grants" => :all}
      user_id = 123
      params = %{}
      query_data = %{aggs: %{}, fields: []}

      query = Query.build_query(permissions, user_id, params, query_data)

      assert %{bool: %{must: %{match_all: %{}}}} = query
    end

    test "builds query with only user_id when both permissions are :none" do
      permissions = %{"manage_grants" => :none, "view_grants" => :none}
      user_id = 123
      params = %{}
      query_data = %{aggs: %{}, fields: []}

      query = Query.build_query(permissions, user_id, params, query_data)

      assert %{bool: %{must: %{term: %{"user_id" => 123}}}} = query
    end

    test "builds query with manage_grants as domain_ids and view_grants as :none" do
      permissions = %{"manage_grants" => [1, 2], "view_grants" => :none}
      user_id = 123
      params = %{}
      query_data = %{aggs: %{}, fields: []}

      query = Query.build_query(permissions, user_id, params, query_data)

      assert %{bool: %{must: %{bool: %{should: [domain_filter, user_filter]}}}} = query
      assert user_filter == %{term: %{"user_id" => 123}}
      assert %{terms: %{"data_structure_version.domain_ids" => [1, 2]}} = domain_filter
    end

    test "builds query with manage_grants as :none and view_grants as domain_ids" do
      permissions = %{"manage_grants" => :none, "view_grants" => [3, 4]}
      user_id = 456
      params = %{}
      query_data = %{aggs: %{}, fields: []}

      query = Query.build_query(permissions, user_id, params, query_data)

      assert %{bool: %{must: %{bool: %{should: [domain_filter, user_filter]}}}} = query
      assert user_filter == %{term: %{"user_id" => 456}}
      assert %{terms: %{"data_structure_version.domain_ids" => [3, 4]}} = domain_filter
    end

    test "builds query with both manage_grants and view_grants as domain_ids" do
      permissions = %{"manage_grants" => [1, 2], "view_grants" => [3, 4]}
      user_id = 789
      params = %{}
      query_data = %{aggs: %{}, fields: []}

      query = Query.build_query(permissions, user_id, params, query_data)

      assert %{bool: %{must: %{bool: %{should: [domain_filter, user_filter]}}}} = query
      assert user_filter == %{term: %{"user_id" => 789}}
      assert %{terms: %{"data_structure_version.domain_ids" => domain_ids}} = domain_filter
      assert Enum.sort(domain_ids) == [1, 2, 3, 4]
    end

    test "builds query with overlapping domain_ids" do
      permissions = %{"manage_grants" => [1, 2, 3], "view_grants" => [2, 3, 4]}
      user_id = 100
      params = %{}
      query_data = %{aggs: %{}, fields: []}

      query = Query.build_query(permissions, user_id, params, query_data)

      assert %{bool: %{must: %{bool: %{should: [domain_filter, _]}}}} = query
      assert %{terms: %{"data_structure_version.domain_ids" => domain_ids}} = domain_filter
      assert Enum.sort(domain_ids) == [1, 2, 3, 4]
    end

    test "builds query with manage_grants as :all and view_grants as domain_ids" do
      permissions = %{"manage_grants" => :all, "view_grants" => [1, 2]}
      user_id = 200
      params = %{}
      query_data = %{aggs: %{}, fields: []}

      query = Query.build_query(permissions, user_id, params, query_data)

      assert %{bool: %{must: %{match_all: %{}}}} = query
    end

    test "builds query with manage_grants as domain_ids and view_grants as :all" do
      permissions = %{"manage_grants" => [1, 2], "view_grants" => :all}
      user_id = 300
      params = %{}
      query_data = %{aggs: %{}, fields: []}

      query = Query.build_query(permissions, user_id, params, query_data)

      assert %{bool: %{must: %{match_all: %{}}}} = query
    end

    test "builds query with missing manage_grants key" do
      permissions = %{"view_grants" => [1, 2]}
      user_id = 400
      params = %{}
      query_data = %{aggs: %{}, fields: []}

      query = Query.build_query(permissions, user_id, params, query_data)

      assert %{bool: %{must: %{bool: %{should: [_domain_filter, user_filter]}}}} = query
      assert user_filter == %{term: %{"user_id" => 400}}
    end

    test "builds query with missing view_grants key" do
      permissions = %{"manage_grants" => [5, 6]}
      user_id = 500
      params = %{}
      query_data = %{aggs: %{}, fields: []}

      query = Query.build_query(permissions, user_id, params, query_data)

      assert %{bool: %{must: %{bool: %{should: [_domain_filter, user_filter]}}}} = query
      assert user_filter == %{term: %{"user_id" => 500}}
    end

    test "builds query with empty permissions map" do
      permissions = %{}
      user_id = 600
      params = %{}
      query_data = %{aggs: %{}, fields: []}

      query = Query.build_query(permissions, user_id, params, query_data)

      assert %{bool: %{must: %{term: %{"user_id" => 600}}}} = query
    end

    test "builds query with filters in params" do
      permissions = %{"manage_grants" => :all, "view_grants" => :all}
      user_id = 700
      params = %{"filters" => %{"status" => ["approved"]}}
      query_data = %{aggs: %{}, fields: []}

      query = Query.build_query(permissions, user_id, params, query_data)

      assert %{bool: %{must: must}} = query
      assert is_map(must) or is_list(must)
    end

    test "builds query with single domain_id" do
      permissions = %{"manage_grants" => [1], "view_grants" => :none}
      user_id = 800
      params = %{}
      query_data = %{aggs: %{}, fields: []}

      query = Query.build_query(permissions, user_id, params, query_data)

      assert %{bool: %{must: %{bool: %{should: [domain_filter, _]}}}} = query
      assert %{term: %{"data_structure_version.domain_ids" => 1}} = domain_filter
    end
  end
end
