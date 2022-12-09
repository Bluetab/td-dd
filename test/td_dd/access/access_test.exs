defmodule TdDd.AccessTest do
  use TdDd.DataCase

  alias Ecto.Changeset
  alias TdDd.Access
  alias TdDd.Repo

  describe "Access.changeset/2" do
    test "validates required fields" do
      assert %{errors: errors} = Access.changeset(%{})
      assert {_, [validation: :required]} = errors[:data_structure_id]
      assert {_, [validation: :required]} = errors[:source_user_name]
      assert {_, [validation: :required]} = errors[:accessed_at]
    end

    test "captures foreign key constraint on data structure" do
      params = %{
        "source_user_name" => "oracle",
        "data_structure_id" => 123,
        "accessed_at" => "2011-12-13 00:00:00"
      }

      assert {:error, %{errors: errors}} =
               Access.changeset(params)
               |> Repo.insert()

      assert errors[:data_structure_id] ==
               {"does not exist",
                [constraint: :foreign, constraint_name: "accesses_data_structure_id_fkey"]}
    end

    test "if user_name not exists do not maps to user_id" do
      params = %{
        "user_name" => "unexisten_user",
        "source_user_name" => "oracle",
        "data_structure_id" => 123,
        "accessed_at" => "2011-12-13 00:00:00"
      }

      changeset = Access.changeset(params)

      assert changeset.valid?
      assert Changeset.get_change(changeset, :user_id) == nil
    end

    test "maps user_name to user_id" do
      %{user_name: user_name, id: user_id} = CacheHelpers.insert_user()

      assert %{"user_name" => user_name}
             |> Access.changeset()
             |> Changeset.fetch_change!(:user_id) == user_id
    end

    test "maps user_external_id to user_id" do
      %{external_id: external_id, id: user_id} = CacheHelpers.insert_user()

      assert %{"user_external_id" => external_id}
             |> Access.changeset()
             |> Changeset.fetch_change!(:user_id) == user_id
    end

    test "can be inserted if valid (user by user_name)" do
      %{user_name: user_name, id: user_id} = CacheHelpers.insert_user()
      %{external_id: data_structure_external_id, id: data_structure_id} = insert(:data_structure)

      params = %{
        "source_user_name" => "oracle",
        "data_structure_id" => data_structure_id,
        "data_structure_external_id" => data_structure_external_id,
        "user_name" => user_name,
        "accessed_at" => "2011-12-13 00:00:00"
      }

      assert {:ok, %Access{} = access} =
               Access.changeset(params)
               |> Repo.insert()

      assert %{
               user_id: ^user_id,
               source_user_name: "oracle",
               data_structure_id: ^data_structure_id,
               data_structure_external_id: ^data_structure_external_id
             } = access
    end

    test "can be inserted if valid (user by user_external_id)" do
      %{external_id: user_external_id, id: user_id} = CacheHelpers.insert_user()
      %{external_id: data_structure_external_id, id: data_structure_id} = insert(:data_structure)

      params = %{
        "source_user_name" => "oracle",
        "data_structure_external_id" => data_structure_external_id,
        "data_structure_id" => data_structure_id,
        "user_external_id" => user_external_id,
        "accessed_at" => "2011-12-13 00:00:00"
      }

      assert {:ok, %Access{} = access} =
               Access.changeset(params)
               |> Repo.insert()

      assert %{
               user_id: ^user_id,
               source_user_name: "oracle",
               data_structure_external_id: ^data_structure_external_id,
               data_structure_id: ^data_structure_id
             } = access
    end
  end
end
