defmodule TdDd.GrantsTest do
  use TdDd.DataCase
  import TdDd.TestOperators
  alias TdDd.Grants

  describe "grants" do
    alias TdDd.Grants.Grant

    @valid_attrs %{
      detail: %{},
      end_date: "2010-04-17T14:00:00.000000Z",
      start_date: "2010-04-17T14:00:00.000000Z",
      user_id: 42
    }
    @update_attrs %{
      detail: %{},
      end_date: "2011-05-18T15:01:01.000000Z",
      start_date: "2011-05-18T15:01:01.000000Z",
      user_id: 43
    }
    @invalid_attrs %{detail: nil, end_date: nil, start_date: nil, user_id: nil}

    test "list_grants/0 returns all grants" do
      grant = insert(:grant)
      assert Grants.list_grants() <|> [grant]
    end

    test "get_grant!/1 returns the grant with given id" do
      grant = insert(:grant)
      assert Grants.get_grant!(grant.id) <~> grant
    end

    test "create_grant/1 with valid data creates a grant" do
      %{id: data_structure_id} = data_structure = insert(:data_structure)
      assert {:ok, %Grant{} = grant} = Grants.create_grant(@valid_attrs, data_structure)
      assert grant.detail == %{}
      assert grant.end_date == DateTime.from_naive!(~N[2010-04-17T14:00:00.000000Z], "Etc/UTC")
      assert grant.start_date == DateTime.from_naive!(~N[2010-04-17T14:00:00.000000Z], "Etc/UTC")
      assert grant.user_id == 42
      assert grant.data_structure_id == data_structure_id
    end

    test "create_grant/1 with invalid data returns error changeset" do
      data_structure = insert(:data_structure)
      assert {:error, %Ecto.Changeset{}} = Grants.create_grant(@invalid_attrs, data_structure)
    end

    test "update_grant/2 with valid data updates the grant" do
      %{user_id: previous_user_id} = grant = insert(:grant)
      assert {:ok, %Grant{} = grant} = Grants.update_grant(grant, @update_attrs)
      assert grant.detail == %{}
      assert grant.end_date == DateTime.from_naive!(~N[2011-05-18T15:01:01.000000Z], "Etc/UTC")
      assert grant.start_date == DateTime.from_naive!(~N[2011-05-18T15:01:01.000000Z], "Etc/UTC")
      assert grant.user_id == previous_user_id
    end

    test "update_grant/2 with invalid data returns error changeset" do
      grant = insert(:grant)
      assert {:error, %Ecto.Changeset{}} = Grants.update_grant(grant, @invalid_attrs)
      assert grant <~> Grants.get_grant!(grant.id)
    end

    test "delete_grant/1 deletes the grant" do
      grant = insert(:grant)
      assert {:ok, %Grant{}} = Grants.delete_grant(grant)
      assert_raise Ecto.NoResultsError, fn -> Grants.get_grant!(grant.id) end
    end
  end
end
