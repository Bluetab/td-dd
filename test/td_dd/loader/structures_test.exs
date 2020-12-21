defmodule TdDd.Loader.StructuresTest do
  use TdDd.DataCase

  alias TdDd.DataStructures.DataStructure
  alias TdDd.Loader.Structures

  setup %{ids: ids} do
    %{id: system_id} = insert(:system)
    ts = DateTime.utc_now() |> DateTime.truncate(:second)

    entries =
      ids
      |> Enum.map(fn id ->
        %{
          external_id: "#{id}",
          domain_id: rem(id, 2),
          inserted_at: ts,
          updated_at: ts,
          system_id: system_id
        }
      end)

    Repo.insert_all(DataStructure, entries)

    [ids: ids]
  end

  describe "bulk_update_domain_id/3" do
    @tag ids: 1..5_000
    test "bulk-updates domain_id iff changed, returns count and affected ids", %{ids: ids} do
      ts = DateTime.utc_now() |> DateTime.truncate(:second)

      assert {0, []} = Structures.bulk_update_domain_id([], 1, ts)

      assert {2_500, updated_ids} =
               ids
               |> Enum.map(&Integer.to_string/1)
               |> Structures.bulk_update_domain_id(1, ts)

      assert length(updated_ids) == 2_500

      assert {0, []} =
               updated_ids
               |> Enum.map(&Integer.to_string/1)
               |> Structures.bulk_update_domain_id(1, ts)
    end

    @tag ids: 1..10
    test "handles nil correctly", %{ids: ids} do
      ts = DateTime.utc_now() |> DateTime.truncate(:second)
      external_ids = Enum.map(ids, &Integer.to_string/1)

      assert {10, _} = Structures.bulk_update_domain_id(external_ids, nil, ts)
      assert {0, []} = Structures.bulk_update_domain_id(external_ids, nil, ts)
    end
  end
end
