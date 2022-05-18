defmodule TdDd.Grants.GrantTest do
  use TdDd.DataCase

  alias Ecto.Changeset
  alias TdDd.Grants.Grant
  alias TdDd.Repo

  setup do
    %{id: user_id, user_name: user_name, external_id: user_external_id} =
      CacheHelpers.insert_user()

    %{id: data_structure_id} = insert(:data_structure)

    [
      user_id: user_id,
      user_name: user_name,
      user_external_id: user_external_id,
      data_structure_id: data_structure_id
    ]
  end

  describe "Grant.changeset/2" do
    test "validates required fields" do
      assert %{errors: errors} = Grant.changeset(%{}, false)
      assert {_, [validation: :required]} = errors[:data_structure_id]
      assert {_, [validation: :required]} = errors[:start_date]
    end

    test "CSV bulk: validates required fields" do
      assert %{errors: errors} = Grant.changeset(%{}, true)
      assert {_, [validation: :required]} = errors[:data_structure_id]
      assert {_, [validation: :required]} = errors[:start_date]
      assert {_, [validation: :required]} = errors[:source_user_name]
    end

    test "maps user_name to user_id", %{user_name: user_name, user_id: user_id} do
      assert %{"user_name" => user_name}
             |> Grant.changeset(false)
             |> Changeset.fetch_change!(:user_id) == user_id
    end

    test "maps user_external_id to user_id", %{
      user_external_id: user_external_id,
      user_id: user_id
    } do
      assert %{"user_external_id" => user_external_id}
             |> Grant.changeset(false)
             |> Changeset.fetch_change!(:user_id) == user_id
    end

    test "cannot use both user_id and user_name", %{user_name: user_name, user_id: user_id} do
      assert %{errors: errors} =
               %{"user_name" => user_name, "user_id" => user_id}
               |> Grant.changeset(false)

      assert {"use either user_id or one of user_name, user_external_id", _} = errors[:user_id]
    end

    test "cannot use both user_id and user_external_id", %{
      user_external_id: user_external_id,
      user_id: user_id
    } do
      assert %{errors: errors} =
               %{"user_external_id" => user_external_id, "user_id" => user_id}
               |> Grant.changeset(false)

      assert {"use either user_id or one of user_name, user_external_id", _} = errors[:user_id]
    end

    test "cannot use both user_name and user_external_id", %{
      user_external_id: user_external_id,
      user_name: user_name
    } do
      assert %{errors: errors} =
               %{"user_external_id" => user_external_id, "user_name" => user_name}
               |> Grant.changeset(false)

      assert {"use either user_name or user_external_id", _} = errors[:user_name_user_external_id]
    end

    test "cannot use all user_id, user_name and user_external_id", %{
      user_name: user_name,
      user_external_id: user_external_id,
      user_id: user_id
    } do
      assert %{errors: errors} =
               %{
                 "user_name" => user_name,
                 "user_external_id" => user_external_id,
                 "user_id" => user_id
               }
               |> Grant.changeset(false)

      assert {"use either user_name or user_external_id", _} = errors[:user_name_user_external_id]
    end

    test "captures foreign key constraint on data structure", %{user_id: user_id} do
      params = %{
        "user_id" => user_id,
        "start_date" => "2021-01-01",
        "end_date" => "2022-01-01"
      }

      assert {:error, %{errors: errors}} =
               %Grant{data_structure_id: 123}
               |> Grant.changeset(params, false)
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
               |> Grant.changeset(params, false)
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
               |> Grant.changeset(params, false)
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
               |> Grant.changeset(params, false)
               |> Repo.insert()

      assert {_, [constraint: :exclusion, constraint_name: "no_overlap"]} = errors[:user_id]
    end

    test "captures exclusion constraint on source_user_name, data structure and date range", %{
      data_structure_id: data_structure_id
    } do
      source_user_name = "source_user_name"

      insert(:grant,
        source_user_name: source_user_name,
        start_date: "2020-01-01",
        end_date: "2020-02-02",
        data_structure_id: data_structure_id
      )

      params = %{
        "source_user_name" => source_user_name,
        "data_structure_id" => data_structure_id,
        "start_date" => "2020-01-02",
        "end_date" => "2021-02-03"
      }

      assert {:error, %{errors: errors}} =
               %Grant{data_structure_id: data_structure_id}
               |> Grant.changeset(params, true)
               |> Repo.insert()

      assert {_, [constraint: :exclusion, constraint_name: "no_overlap_source_user_name"]} =
               errors[:source_user_name]
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
               |> Grant.changeset(params, false)
               |> Repo.insert()

      assert %{
               user_id: ^user_id,
               start_date: ~D[2020-01-02],
               end_date: ~D[2021-02-03],
               data_structure_id: ^data_structure_id
             } = grant
    end

    test "CSV bulk: can be inserted if valid, user absent, source_user_name present", %{
      data_structure_id: data_structure_id
    } do
      params = %{
        "source_user_name" => "source_user_name",
        "data_structure_id" => data_structure_id,
        "start_date" => "2020-01-02",
        "end_date" => "2021-02-03"
      }

      assert {:ok, %Grant{} = grant} =
               %Grant{data_structure_id: data_structure_id}
               |> Grant.changeset(params, true)
               |> Repo.insert()

      assert %{
               user_id: nil,
               start_date: ~D[2020-01-02],
               end_date: ~D[2021-02-03],
               data_structure_id: ^data_structure_id
             } = grant
    end

    test "CSV bulk: can be inserted if valid, user present, source_user_name present", %{
      user_id: user_id,
      user_name: user_name,
      data_structure_id: data_structure_id
    } do
      params = %{
        "user_name" => user_name,
        "source_user_name" => "source_user_name",
        "data_structure_id" => data_structure_id,
        "start_date" => "2020-01-02",
        "end_date" => "2021-02-03"
      }

      assert {:ok, %Grant{} = grant} =
               %Grant{data_structure_id: data_structure_id}
               |> Grant.changeset(params, true)
               |> Repo.insert()

      assert %{
               user_id: ^user_id,
               source_user_name: "source_user_name",
               start_date: ~D[2020-01-02],
               end_date: ~D[2021-02-03],
               data_structure_id: ^data_structure_id
             } = grant
    end
  end
end
