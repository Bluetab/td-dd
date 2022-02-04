defmodule TdDd.Access.BulkLoadTest do
  use TdDd.DataCase

  alias TdDd.Access
  alias TdDd.Access.BulkLoad

  setup do
    %{id: data_structure_id, external_id: ds_external_id} = insert(:data_structure)
    %{id: _user_id, user_name: user_name} = user = CacheHelpers.insert_user()
    accesses = [
      %{
        data_structure_external_id: ds_external_id,
        source_user_name: "oracle",
        user_name: user_name,
        details: %{
          db: "some_db_1",
          table: "some_table_1"
        }
      },
      %{
        data_structure_external_id: ds_external_id,
        source_user_name: "postgres",
        user_name: user_name,
        details: %{
          db: "some_db_2",
          table: "some_table_2"
        }
      }
    ]

    [data_structure_id: data_structure_id, accesses: accesses, ds_external_id: ds_external_id, user: user]
  end

  describe "bulk_load/2" do
    test "return ids from inserted rules", %{accesses: accesses, ds_external_id: ds_external_id, user: %{id: user_id, user_name: user_name}} do
      {entries_count, _result} = BulkLoad.bulk_load(accesses)
      inserted_accesses = Repo.all(Access) |> Repo.preload(:data_structure)

      assert Enum.count(inserted_accesses) == entries_count
      assert [
        %TdDd.Access{
          data_structure: %{external_id: ^ds_external_id},
          details: %{"db" => "some_db_1", "table" => "some_table_1"},
          source_user_name: "oracle",
          user_external_id: nil,
          user_id: ^user_id,
          user_name: ^user_name
        },
        %TdDd.Access{
          data_structure: %{external_id: ^ds_external_id},
          details: %{"db" => "some_db_2", "table" => "some_table_2"},
          source_user_name: "postgres",
          user_external_id: nil,
          user_id: ^user_id,
          user_name: ^user_name
        }
      ] = inserted_accesses
    end
  end


end
