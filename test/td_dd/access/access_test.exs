defmodule TdDd.AccessTest do

  use TdDd.DataCase

  alias Ecto.Changeset
  alias TdDd.Access
  alias TdDd.Repo

  setup do
    %{external_id: data_structure_external_id} = insert(:data_structure)
    user = CacheHelpers.insert_user()

    [data_structure_external_id: data_structure_external_id, user: user]
  end

  describe "Access.changeset/2" do
    test "validates required fields" do
      assert %{errors: errors} = Access.changeset(%{})
      assert {_, [validation: :required]} = errors[:data_structure_external_id]
      assert {_, [validation: :required]} = errors[:source_user_name]
    end

    test "captures foreign key constraint on data structure" do
      params = %{
        "source_user_name" => "oracle",
        "data_structure_external_id" => "non_existent_external_id"
      }

      assert {:error, %{errors: errors}} =
               Access.changeset(params)
               |> Repo.insert

      assert {"does not exist", [{:constraint, :foreign}, {:constraint_name, "accesses_data_structure_external_id_fkey"}]} =
               errors[:data_structure_external_id]
    end

    test "maps user_name to user_id", %{user: %{user_name: user_name, id: user_id}} do
      assert %{"user_name" => user_name}
             |> Access.changeset()
             |> Changeset.fetch_change!(:user_id) == user_id
    end

    test "maps user_external_id to user_id", %{user: %{external_id: user_external_id, id: user_id}} do
      assert %{"user_external_id" => user_external_id}
             |> Access.changeset()
             |> Changeset.fetch_change!(:user_id) == user_id
    end

    test "can be inserted if valid (user by user_name)", %{
      user: %{user_name: user_name, id: user_id},
      data_structure_external_id: data_structure_external_id
    } do
      params = %{
        "source_user_name" => "oracle",
        "data_structure_external_id" => data_structure_external_id,
        "user_name" => user_name
      }

      assert {:ok, %Access{} = access} =
        Access.changeset(params)
        |> Repo.insert()

      assert %{
        user_id: ^user_id,
        source_user_name: "oracle",
        user_name: ^user_name, # Only user_id will be needed, just to check
        data_structure_external_id: ^data_structure_external_id
      } = access
    end

    test "can be inserted if valid (user by user_external_id)", %{
      user: %{external_id: user_external_id, id: user_id},
      data_structure_external_id: data_structure_external_id
    } do
      params = %{
        "source_user_name" => "oracle",
        "data_structure_external_id" => data_structure_external_id,
        "user_external_id" => user_external_id
      }

      assert {:ok, %Access{} = access} =
        Access.changeset(params)
        |> Repo.insert()

      assert %{
        user_id: ^user_id,
        source_user_name: "oracle",
        user_external_id: ^user_external_id, # Only user_id will be needed, just to check
        data_structure_external_id: ^data_structure_external_id
      } = access
    end
  end
end
