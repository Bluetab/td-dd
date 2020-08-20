defmodule TdDd.UserSearchFiltersTest do
  use TdDd.DataCase

  alias TdDd.UserSearchFilters

  describe "user_search_filters" do
    alias TdDd.UserSearchFilters.UserSearchFilter

    @valid_attrs %{filters: %{}, name: "some name", user_id: 42}
    @update_attrs %{filters: %{}, name: "some updated name", user_id: 43}
    @invalid_attrs %{filters: nil, name: nil, user_id: nil}

    def user_search_filter_fixture(attrs \\ %{}) do
      {:ok, user_search_filter} =
        attrs
        |> Enum.into(@valid_attrs)
        |> UserSearchFilters.create_user_search_filter()

      user_search_filter
    end

    test "list_user_search_filters/0 returns all user_search_filters" do
      user_search_filter = user_search_filter_fixture()
      assert UserSearchFilters.list_user_search_filters() == [user_search_filter]
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
    end

    test "create_user_search_filter/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               UserSearchFilters.create_user_search_filter(@invalid_attrs)
    end

    test "update_user_search_filter/2 with valid data updates the user_search_filter" do
      user_search_filter = user_search_filter_fixture()

      assert {:ok, %UserSearchFilter{} = user_search_filter} =
               UserSearchFilters.update_user_search_filter(user_search_filter, @update_attrs)

      assert user_search_filter.filters == %{}
      assert user_search_filter.name == "some updated name"
      assert user_search_filter.user_id == 43
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
