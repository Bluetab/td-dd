defmodule TdDd.UserSearchFiltersTest do
  use TdDd.DataCase

  alias TdDd.UserSearchFilters
  alias TdDd.UserSearchFilters.UserSearchFilter

  describe "UserSearchFilters.list_user_search_filters/1" do
    test "returns all user_search_filters" do
      user_search_filter = insert(:user_search_filter)
      assert UserSearchFilters.list_user_search_filters(%{}) == [user_search_filter]
    end

    test "filters by scope" do
      usf = insert(:user_search_filter, scope: "data_structure")
      insert(:user_search_filter, scope: "rule")
      assert UserSearchFilters.list_user_search_filters(%{"scope" => "data_structure"}) == [usf]
    end
  end

  describe "list_user_search_filters/2" do
    test "filters by scope and user_id" do
      %{scope: scope} = usf = insert(:user_search_filter, user_id: 1)
      insert(:user_search_filter, user_id: 2)
      insert(:user_search_filter, is_global: true)
      claims = %{user_id: 1, role: "admin"}
      assert UserSearchFilters.list_user_search_filters(%{"scope" => scope}, claims) == [usf]
    end

    test "includes global filters for admin user" do
      %{user_id: user_id} = claims = build(:claims, role: "admin")

      usf1 = insert(:user_search_filter, scope: "rule", user_id: user_id)
      usf2 = insert(:user_search_filter, scope: "rule", is_global: true)
      insert(:user_search_filter, scope: "rule", user_id: 99)

      assert UserSearchFilters.list_user_search_filters(%{"scope" => "rule"}, claims)
             |> assert_lists_equal([usf1, usf2])
    end

    test "filters by taxonomy for non-admin user" do
      %{id: domain_id} = CacheHelpers.insert_domain()
      %{user_id: user_id} = claims = build(:claims, role: "user")
      CacheHelpers.put_session_permissions(claims, %{"view_quality_rule" => [domain_id]})

      usf1 = insert(:user_search_filter, scope: "rule", user_id: user_id)
      usf2 = insert(:user_search_filter, scope: "rule", is_global: true)

      usf3 =
        insert(:user_search_filter,
          scope: "rule",
          is_global: true,
          filters: %{"taxonomy" => [domain_id]}
        )

      insert(:user_search_filter, scope: "rule", is_global: true, filters: %{"taxonomy" => [99]})

      assert UserSearchFilters.list_user_search_filters(%{"scope" => "rule"}, claims)
             |> assert_lists_equal([usf1, usf2, usf3])
    end
  end

  describe "get_user_search_filter!/1" do
    test "returns the user_search_filter with given id" do
      user_search_filter = insert(:user_search_filter)

      assert UserSearchFilters.get_user_search_filter!(user_search_filter.id) ==
               user_search_filter
    end
  end

  describe "create_user_search_filter/1" do
    test "with valid data creates a user_search_filter" do
      %{filters: filters, name: name, user_id: user_id, scope: scope, is_global: is_global} =
        params = params_for(:user_search_filter)

      assert {:ok, %UserSearchFilter{} = user_search_filter} =
               UserSearchFilters.create_user_search_filter(params)

      assert user_search_filter.filters == filters
      assert user_search_filter.name == name
      assert user_search_filter.user_id == user_id
      assert user_search_filter.scope == scope
      assert user_search_filter.is_global == is_global
    end

    test "with invalid data returns error changeset" do
      params = %{filters: nil, name: nil, user_id: nil, scope: nil}
      assert {:error, %Ecto.Changeset{}} = UserSearchFilters.create_user_search_filter(params)
    end

    test "cannot create invalid scope" do
      params = params_for(:user_search_filter) |> Map.put(:scope, :invalid_scope)
      assert {:error, %Ecto.Changeset{}} = UserSearchFilters.create_user_search_filter(params)
    end
  end

  describe "delete_user_search_filter/1" do
    test "deletes the user_search_filter" do
      user_search_filter = insert(:user_search_filter)

      assert {:ok, %UserSearchFilter{}} =
               UserSearchFilters.delete_user_search_filter(user_search_filter)

      assert_raise Ecto.NoResultsError, fn ->
        UserSearchFilters.get_user_search_filter!(user_search_filter.id)
      end
    end
  end

  test "retrive global data_structure filter when role by default " do
    CacheHelpers.put_default_permissions(["view_data_structure"])

    %{user_id: user_id} = claims = build(:claims, role: "user")
    %{user_id: user_id2} = build(:claims, role: "bad_user")

    usf1 = insert(:user_search_filter, is_global: true, user_id: user_id, scope: "data_structure")

    usf2 =
      insert(:user_search_filter, is_global: true, user_id: user_id2, scope: "data_structure")

    insert(:user_search_filter, is_global: false, user_id: user_id2, scope: "data_structure")

    assert UserSearchFilters.list_user_search_filters(%{"scope" => "data_structure"}, claims)
           |> assert_lists_equal([usf1, usf2])
  end

  test "retrive global quality_rule filter when role by default " do
    CacheHelpers.put_default_permissions(["view_quality_rule"])

    %{user_id: user_id} = claims = build(:claims, role: "user")
    %{user_id: user_id2} = build(:claims, role: "bad_user")

    usf4 = insert(:user_search_filter, is_global: true, user_id: user_id, scope: "rule")
    usf5 = insert(:user_search_filter, is_global: true, user_id: user_id2, scope: "rule")
    insert(:user_search_filter, is_global: false, user_id: user_id2, scope: "rule")

    usf7 =
      insert(:user_search_filter, is_global: true, user_id: user_id, scope: "rule_implementation")

    usf8 =
      insert(:user_search_filter, is_global: true, user_id: user_id2, scope: "rule_implementation")

    insert(:user_search_filter, is_global: false, user_id: user_id2, scope: "rule_implementation")

    assert UserSearchFilters.list_user_search_filters(%{"scope" => "rule"}, claims)
           |> assert_lists_equal([usf4, usf5])

    assert UserSearchFilters.list_user_search_filters(%{"scope" => "rule_implementation"}, claims)
           |> assert_lists_equal([usf7, usf8])
  end
end
