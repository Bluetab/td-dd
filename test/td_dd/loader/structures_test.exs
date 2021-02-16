defmodule TdDd.Loader.StructuresTest do
  use TdDd.DataCase

  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.Loader.Structures

  setup %{ids: ids} do
    %{id: system_id} = insert(:system)
    ts = timestamp()

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

  describe "update_domain_ids/2" do
    @tag ids: 1..10
    test "updates domain_id only if changed" do
      ts = timestamp()
      new_domain_id = 42
      records = [%{domain_id: 1, external_id: "1"}, %{domain_id: new_domain_id, external_id: "2"}]
      assert {:ok, {1, [structure_id]}} = Structures.update_domain_ids(records, ts)
      assert %{domain_id: ^new_domain_id} = Repo.get!(DataStructure, structure_id)
    end
  end

  describe "update_source_ids/2" do
    @tag ids: 1..10
    test "updates source_id only if changed and source_id not nil" do
      ts = timestamp()

      records =
        Enum.map(1..10, fn id ->
          %{
            external_id: "#{id}"
          }
        end)

      external_ids = Enum.map(records, & &1.external_id)
      structures = DataStructures.list_data_structures(%{external_id: external_ids})
      ids = Enum.map(structures, & &1.id)
      assert {0, []} = Structures.update_source_ids(records, nil, ts)
      assert {10, ^ids} = Structures.update_source_ids(records, 1, ts)
      assert {0, []} = Structures.update_source_ids(records, 1, ts)
      updated_ids = Enum.take(ids, 5)
      assert {5, ^updated_ids} = Structures.update_source_ids(Enum.take(records, 5), 2, ts)
      updated_ids = Enum.take(ids, -5)
      assert {5, ^updated_ids} = Structures.update_source_ids(records, 2, ts)
      structures = DataStructures.list_data_structures(%{external_id: external_ids})
      assert Enum.all?(structures, &(&1.source_id == 2))
    end
  end

  describe "bulk_update_domain_id/3" do
    @tag ids: 1..5_000
    test "bulk-updates domain_id if changed, returns count and affected ids", %{ids: ids} do
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

  defp timestamp, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
