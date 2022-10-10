defmodule TdDd.UserSearchFiltersTest do
  use TdDd.DataCase

  import TdDd.TestOperators

  alias TdDd.UserSearchFilters

  describe "user_search_filters" do
    alias TdDd.UserSearchFilters.UserSearchFilter

    @valid_attrs %{
      filters: %{},
      name: "some name",
      user_id: 42,
      scope: :data_structure,
      is_global: true
    }
    @update_attrs %{
      filters: %{},
      name: "some updated name",
      user_id: 43,
      scope: :rule,
      is_global: false
    }
    @invalid_attrs %{filters: nil, name: nil, user_id: nil, scope: nil}

    def user_search_filter_fixture(attrs \\ %{}) do
      {:ok, user_search_filter} =
        attrs
        |> Enum.into(@valid_attrs)
        |> UserSearchFilters.create_user_search_filter()

      user_search_filter
    end

    test "list_user_search_filters/1 returns all user_search_filters" do
      user_search_filter = user_search_filter_fixture()
      assert UserSearchFilters.list_user_search_filters() == [user_search_filter]
    end

    test "list_user_search_filters/1 filters by scope" do
      usf = insert(:user_search_filter, scope: "data_structure")
      insert(:user_search_filter, scope: "rule")
      assert [usf] <|> UserSearchFilters.list_user_search_filters(%{"scope" => "data_structure"})
    end

    test "list_user_search_filters/1 filters by user_id" do
      usf = insert(:user_search_filter, user_id: 1)
      insert(:user_search_filter, user_id: 2)
      insert(:user_search_filter, is_global: true)
      assert [usf] <|> UserSearchFilters.list_user_search_filters(%{"user_id" => 1})
    end

    test "list_user_search_filters/1 includes global results for all taxonomies" do
      usf1 = insert(:user_search_filter, user_id: 1)
      usf2 = insert(:user_search_filter, is_global: true)
      insert(:user_search_filter, user_id: 2)

      assert [usf1, usf2]
             <|> UserSearchFilters.list_user_search_filters(%{
               "user_id" => 1,
               "with_globals" => :all
             })
    end

    test "list_user_search_filters/1 will not duplicate filters" do
      usf = insert(:user_search_filter, user_id: 1, is_global: true)
      insert(:user_search_filter, user_id: 2)

      assert [usf]
             <|> UserSearchFilters.list_user_search_filters(%{
               "user_id" => 1,
               "with_globals" => :all
             })
    end

    test "list_user_search_filters/1 filters by taxonomy filters on globals" do
      usf1 = insert(:user_search_filter, user_id: 1)
      usf2 = insert(:user_search_filter, user_id: 2, is_global: true)

      usf3 =
        insert(:user_search_filter,
          user_id: 2,
          is_global: true,
          filters: %{"taxonomy" => [1, 2, 3]}
        )

      insert(:user_search_filter, user_id: 2, filters: %{"taxonomy" => [1, 2, 3]})

      insert(:user_search_filter, user_id: 2, is_global: true, filters: %{"taxonomy" => [7, 8, 9]})

      insert(:user_search_filter, user_id: 2)

      assert [usf1, usf2, usf3]
             <|> UserSearchFilters.list_user_search_filters(%{
               "user_id" => 1,
               "with_globals" => [3, 4, 5]
             })
    end

    test "get_user_search_filter!/1 returns the user_search_filter with given id" do
      user_search_filter = user_search_filter_fixture()

      assert UserSearchFilters.get_user_search_filter!(user_search_filter.id) ==
               user_search_filter
    end

    test "create_user_search_filter/1 with valid data creates a user_search_filter" do
      assert {:ok, %UserSearchFilter{} = user_search_filter} =
               UserSearchFilters.create_user_search_filter(@valid_attrs)

      assert user_search_filter.filters == %{}
      assert user_search_filter.name == "some name"
      assert user_search_filter.user_id == 42
      assert user_search_filter.scope == :data_structure
      assert user_search_filter.is_global == true
    end

    test "create_user_search_filter/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               UserSearchFilters.create_user_search_filter(@invalid_attrs)
    end

    test "cannot create invalid scope" do
      attrs = Map.put(@valid_attrs, :scope, :invalid_scope)
      assert {:error, %Ecto.Changeset{}} = UserSearchFilters.create_user_search_filter(attrs)
    end

    test "update_user_search_filter/2 with valid data updates the user_search_filter" do
      user_search_filter = user_search_filter_fixture()

      assert {:ok, %UserSearchFilter{} = user_search_filter} =
               UserSearchFilters.update_user_search_filter(user_search_filter, @update_attrs)

      assert user_search_filter.filters == %{}
      assert user_search_filter.name == "some updated name"
      assert user_search_filter.user_id == 43
      assert user_search_filter.scope == :rule
      assert user_search_filter.is_global == false
    end

    test "update_user_search_filter/2 with invalid data returns error changeset" do
      user_search_filter = user_search_filter_fixture()

      assert {:error, %Ecto.Changeset{}} =
               UserSearchFilters.update_user_search_filter(user_search_filter, @invalid_attrs)

      assert user_search_filter ==
               UserSearchFilters.get_user_search_filter!(user_search_filter.id)
    end

    test "delete_user_search_filter/1 deletes the user_search_filter" do
      user_search_filter = user_search_filter_fixture()

      assert {:ok, %UserSearchFilter{}} =
               UserSearchFilters.delete_user_search_filter(user_search_filter)

      assert_raise Ecto.NoResultsError, fn ->
        UserSearchFilters.get_user_search_filter!(user_search_filter.id)
      end
    end

    test "change_user_search_filter/1 returns a user_search_filter changeset" do
      user_search_filter = user_search_filter_fixture()
      assert %Ecto.Changeset{} = UserSearchFilters.change_user_search_filter(user_search_filter)
    end
  end
end
