defmodule TdDd.Grants.GrantTest do
  use TdDd.DataCase

  alias Ecto.Changeset
  alias TdDd.Grants.Grant
  alias TdDd.Repo

  setup do
    %{id: user_id, user_name: user_name} = CacheHelpers.insert_user()
    %{id: data_structure_id} = insert(:data_structure)

    [user_id: user_id, user_name: user_name, data_structure_id: data_structure_id]
  end

  describe "Grant.changeset/2" do
    test "validates required fields" do
      assert %{errors: errors} = Grant.changeset(%{})
      assert {_, [validation: :required]} = errors[:data_structure_id]
      assert {_, [validation: :required]} = errors[:user_id]
      assert {_, [validation: :required]} = errors[:start_date]
    end

    test "maps user_name to user_id", %{user_name: user_name, user_id: user_id} do
      assert %{"user_name" => user_name}
             |> Grant.changeset()
             |> Changeset.fetch_change!(:user_id) == user_id
    end

    test "captures foreign key constraint on data structure", %{user_id: user_id} do
      params = %{
        "user_id" => user_id,
        "start_date" => "2021-01-01",
        "end_date" => "2022-01-01"
      }

      assert {:error, %{errors: errors}} =
               %Grant{data_structure_id: 123}
               |> Grant.changeset(params)
               |> Repo.insert()

      assert {_, [{:constraint, :foreign}, {:constraint_name, "grants_data_structure_id_fkey"}]} =
               errors[:data_structure_id]
    end

    test "captures check constraint on date range", %{
      user_id: user_id,
      data_structure_id: data_structure_id
    } do
      params = %{
        "user_id" => user_id,
        "start_date" => "2022-01-01",
        "end_date" => "2021-01-01"
      }

      assert {:error, %{errors: errors}} =
               %Grant{data_structure_id: data_structure_id}
               |> Grant.changeset(params)
               |> Repo.insert()

      assert {_, [constraint: :check, constraint_name: "date_range"]} = errors[:end_date]
    end

    test "allows a date range containing a single day", %{
      user_id: user_id,
      data_structure_id: data_structure_id
    } do
      params = %{
        "user_id" => user_id,
        "start_date" => "2021-01-01",
        "end_date" => "2021-01-01"
      }

      assert {:ok, %Grant{} = grant} =
               %Grant{data_structure_id: data_structure_id}
               |> Grant.changeset(params)
               |> Repo.insert()

      assert %{start_date: ~D[2021-01-01], end_date: ~D[2021-01-01]} = grant
    end

    test "captures exclusion constraint on user, data structure and date range", %{
      user_id: user_id,
      data_structure_id: data_structure_id
    } do
      insert(:grant,
        user_id: user_id,
        start_date: "2020-01-01",
        end_date: "2020-02-02",
        data_structure_id: data_structure_id
      )

      params = %{
        "user_id" => user_id,
        "data_structure_id" => data_structure_id,
        "start_date" => "2020-01-02",
        "end_date" => "2021-02-03"
      }

      assert {:error, %{errors: errors}} =
               %Grant{data_structure_id: data_structure_id}
               |> Grant.changeset(params)
               |> Repo.insert()

      assert {_, [constraint: :exclusion, constraint_name: "no_overlap"]} = errors[:user_id]
    end

    test "can be inserted if valid", %{
      user_id: user_id,
      user_name: user_name,
      data_structure_id: data_structure_id
    } do
      params = %{
        "user_name" => user_name,
        "data_structure_id" => data_structure_id,
        "start_date" => "2020-01-02",
        "end_date" => "2021-02-03"
      }

      assert {:ok, %Grant{} = grant} =
               %Grant{data_structure_id: data_structure_id}
               |> Grant.changeset(params)
               |> Repo.insert()

      assert %{
               user_id: ^user_id,
               start_date: ~D[2020-01-02],
               end_date: ~D[2021-02-03],
               data_structure_id: ^data_structure_id
             } = grant
    end
  end
end
