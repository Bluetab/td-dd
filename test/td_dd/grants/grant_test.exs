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

  describe "Grant.common_changeset/2" do
    test "validates required fields" do
      assert %{errors: errors} = Grant.common_changeset(%Grant{}, %{})
      assert {_, [validation: :required]} = errors[:data_structure_id]
      assert {_, [validation: :required]} = errors[:start_date]
    end

    test "maps user_name to user_id", %{user_name: user_name, user_id: user_id} do
      assert %Grant{}
             |> Grant.common_changeset(%{"user_name" => user_name})
             |> Changeset.fetch_change!(:user_id) == user_id
    end

    test "maps user_external_id to user_id", %{
      user_external_id: user_external_id,
      user_id: user_id
    } do
      assert %Grant{}
             |> Grant.common_changeset(%{"user_external_id" => user_external_id})
             |> Changeset.fetch_change!(:user_id) == user_id
    end

    test "cannot use both user_id and user_name", %{user_name: user_name, user_id: user_id} do
      assert %{errors: errors} =
               Grant.common_changeset(%Grant{}, %{"user_name" => user_name, "user_id" => user_id})

      assert {"use either user_id or one of user_name, user_external_id", _} = errors[:user_id]
    end

    test "cannot use both user_id and user_external_id", %{
      user_external_id: user_external_id,
      user_id: user_id
    } do
      assert %{errors: errors} =
               Grant.common_changeset(%Grant{}, %{
                 "user_external_id" => user_external_id,
                 "user_id" => user_id,
                 "source_user_name" => "source_user_name"
               })

      assert {"use either user_id or one of user_name, user_external_id", _} = errors[:user_id]
    end

    test "cannot use both user_name and user_external_id", %{
      user_external_id: user_external_id,
      user_name: user_name
    } do
      assert %{errors: errors} =
               Grant.common_changeset(%Grant{}, %{
                 "user_external_id" => user_external_id,
                 "user_name" => user_name,
                 "source_user_name" => "source_user_name"
               })

      assert {"use either user_name or user_external_id", _} = errors[:user_name_user_external_id]
    end

    test "cannot use all user_id, user_name and user_external_id", %{
      user_name: user_name,
      user_external_id: user_external_id,
      user_id: user_id
    } do
      assert %{errors: errors} =
               Grant.common_changeset(%Grant{}, %{
                 "user_name" => user_name,
                 "user_external_id" => user_external_id,
                 "user_id" => user_id,
                 "source_user_name" => "source_user_name"
               })

      assert {"use either user_name or user_external_id", _} = errors[:user_name_user_external_id]
    end

    test "captures foreign key constraint on data structure", %{user_id: user_id} do
      params = %{
        "user_id" => user_id,
        "start_date" => "2021-01-01",
        "end_date" => "2022-01-01",
        "source_user_name" => "source_user_name"
      }

      assert {:error, %{errors: errors}} =
               %Grant{data_structure_id: 123}
               |> Grant.common_changeset(params)
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
        "end_date" => "2021-01-01",
        "source_user_name" => "source_user_name"
      }

      assert {:error, %{errors: errors}} =
               %Grant{data_structure_id: data_structure_id}
               |> Grant.common_changeset(params)
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
        "end_date" => "2021-01-01",
        "source_user_name" => "source_user_name"
      }

      assert {:ok, %Grant{} = grant} =
               %Grant{data_structure_id: data_structure_id}
               |> Grant.common_changeset(params)
               |> Repo.insert()

      assert %{start_date: ~D[2021-01-01], end_date: ~D[2021-01-01]} = grant
    end

    test "captures exclusion constraint on source_user_name, external_ref, data structure, date range",
         %{
           user_id: user_id,
           data_structure_id: data_structure_id
         } do
      insert(:grant,
        user_id: user_id,
        start_date: "2020-01-01",
        end_date: "2020-02-02",
        source_user_name: "source_user_name",
        data_structure_id: data_structure_id,
        external_ref: "boo"
      )

      params = %{
        "data_structure_id" => data_structure_id,
        "start_date" => "2020-01-02",
        "end_date" => "2021-02-03",
        "source_user_name" => "source_user_name",
        "external_ref" => "boo"
      }

      assert {:error, %{errors: errors}} =
               %Grant{data_structure_id: data_structure_id}
               |> Grant.common_changeset(params)
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
        "end_date" => "2021-02-03",
        "source_user_name" => "source_user_name"
      }

      assert {:ok, %Grant{} = grant} =
               %Grant{data_structure_id: data_structure_id}
               |> Grant.common_changeset(params)
               |> Repo.insert()

      assert %{
               user_id: ^user_id,
               start_date: ~D[2020-01-02],
               end_date: ~D[2021-02-03],
               data_structure_id: ^data_structure_id
             } = grant
    end
  end

  describe "Grant.create_changeset/2" do
    test "CSV bulk: validates required fields" do
      assert %{errors: errors} = Grant.create_changeset(%{}, true)
      assert {_, [validation: :required]} = errors[:data_structure_id]
      assert {_, [validation: :required]} = errors[:start_date]
      assert {_, [validation: :required]} = errors[:source_user_name]
    end

    test "CSV bulk: captures exclusion constraint on source_user_name, external_ref, data structure and date range",
         %{
           data_structure_id: data_structure_id
         } do
      source_user_name = "source_user_name"

      insert(:grant,
        source_user_name: source_user_name,
        start_date: "2020-01-01",
        end_date: "2020-02-02",
        external_ref: "foo",
        data_structure_id: data_structure_id
      )

      params = %{
        "source_user_name" => source_user_name,
        "data_structure_id" => data_structure_id,
        "start_date" => "2020-01-02",
        "end_date" => "2021-02-03",
        "external_ref" => "foo"
      }

      assert {:error, %{errors: errors}} =
               %Grant{data_structure_id: data_structure_id}
               |> Grant.create_changeset(params, true)
               |> Repo.insert()

      assert {_, [constraint: :exclusion, constraint_name: "no_overlap_source_user_name"]} =
               errors[:source_user_name]
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
               |> Grant.create_changeset(params, true)
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
               |> Grant.create_changeset(params, true)
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

  describe "Grant.update_changeset/2" do
    test "updates grant with valid data" do
      grant = insert(:grant)
      detail = %{detail_key: "detail_value"}
      params = %{detail: detail}

      assert {:ok, %Grant{} = grant} =
               Grant.update_changeset(grant, params)
               |> Repo.update()

      assert %{detail: ^detail} = grant
    end
  end
end
