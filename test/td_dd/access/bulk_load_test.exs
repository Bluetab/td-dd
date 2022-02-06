defmodule TdDd.Access.BulkLoadTest do
  use TdDd.DataCase

  alias TdDd.Access
  alias TdDd.Access.BulkLoad

  setup do
    %{id: data_structure_id, external_id: ds_external_id} = insert(:data_structure)
    %{id: _user_id, user_name: user_name} = user = CacheHelpers.insert_user()

    accesses = [
      %{
        "data_structure_external_id" => ds_external_id,
        "source_user_name" => "tld.domain.oracle",
        "user_name" => user_name,
        "accessed_at" => "2011-12-13 00:00:00",
        "details" => %{
          "db" => "some_db_1",
          "table" => "some_table_1"
        }
      },
      %{
        "data_structure_external_id" => ds_external_id,
        "source_user_name" => "tld.domain.postgres",
        "user_name" => user_name,
        "accessed_at" => "2011-12-13 00:00:02",
        "details" => %{
          "db" => "some_db_2",
          "table" => "some_table_2"
        }
      },
      %{
        "data_structure_external_id" => ds_external_id,
        "source_user_name" => "tld.domain.postgres",
        "details" => %{
          "db" => "some_db_3",
          "table" => "some_table_3"
        }
      }
    ]

    bad_accesses = [
      %{
        "data_structure_external_id" => "inexistent_id_1",
        "source_user_name" => "tld.domain.oracle",
        "user_name" => user_name,
        "details" => %{
          "db" => "some_db_9",
          "table" => "some_table_9"
        }
      },
      %{
        "data_structure_external_id" => "inexistent_id_2",
        "source_user_name" => "tld.domain.postgres",
        "user_name" => user_name,
        "details" => %{
          "db" => "some_db_8",
          "table" => "some_table_8"
        }
      },
      %{
        "data_structure_external_id" => ds_external_id,
        "user_name" => user_name,
        "details" => %{
          "db" => "some_db_7",
          "table" => "some_table_7"
        }
      },
      %{
        "data_structure_external_id" => ds_external_id,
        "source_user_name" => 1234,
        "user_name" => user_name,
        "details" => %{
          "db" => "some_db_6",
          "table" => "some_table_6"
        }
      }
    ]

    [
      data_structure_id: data_structure_id,
      accesses: accesses,
      bad_accesses: bad_accesses,
      ds_external_id: ds_external_id,
      user: user
    ]
  end

  describe "bulk_load/2" do
    test "mixed good and bad accesses", %{
      accesses: accesses,
      bad_accesses: bad_accesses,
      ds_external_id: ds_external_id,
      user: %{id: user_id, user_name: user_name}
    } do
      {entries_count, invalid_changesets, inexistent_external_ids} =
        BulkLoad.bulk_load(accesses ++ bad_accesses)

      inserted_accesses = Repo.all(Access) |> Repo.preload(:data_structure)

      assert Enum.count(inserted_accesses) == entries_count

      assert [
               %TdDd.Access{
                 data_structure: %{external_id: ^ds_external_id},
                 details: %{"db" => "some_db_1", "table" => "some_table_1"},
                 source_user_name: "tld.domain.oracle",
                 user_external_id: nil,
                 user_id: ^user_id,
                 user_name: ^user_name
               },
               %TdDd.Access{
                 data_structure: %{external_id: ^ds_external_id},
                 details: %{"db" => "some_db_2", "table" => "some_table_2"},
                 source_user_name: "tld.domain.postgres",
                 user_external_id: nil,
                 user_id: ^user_id,
                 user_name: ^user_name
               },
               %TdDd.Access{
                 data_structure: %{external_id: ^ds_external_id},
                 details: %{"db" => "some_db_3", "table" => "some_table_3"},
                 source_user_name: "tld.domain.postgres",
                 user_external_id: nil,
                 user_id: nil
               }
             ] = inserted_accesses

      assert [
               %Ecto.Changeset{
                 changes: %{
                   user_id: ^user_id
                 },
                 errors: [
                   source_user_name: {
                     "can't be blank",
                     [
                       validation: :required
                     ]
                   }
                 ],
                 valid?: false
               },
               %Ecto.Changeset{
                 changes: %{
                   user_id: ^user_id
                 },
                 errors: [
                   source_user_name: {
                     "is invalid",
                     [
                       type: :string,
                       validation: :cast
                     ]
                   }
                 ],
                 valid?: false
               }
             ] = invalid_changesets

      assert [
               "inexistent_id_1",
               "inexistent_id_2"
             ] = inexistent_external_ids
    end
  end
end
