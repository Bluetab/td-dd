defmodule TdDd.DataStructurePurgeTest do
  use TdDd.DataStructureCase

  alias TdDd.DataStructures.DataStructurePurge
  alias TdDd.Search.MockIndexWorker

  setup_all do
    start_supervised(MockIndexWorker)
    :ok
  end

  @moduletag sandbox: :shared

  setup do
    data_structure = insert(:data_structure)

    [data_structure: data_structure]
  end

  describe "data_structure_purge/0" do
    test "delete old data structure version", %{
      data_structure: %{id: id}
    } do
      now = DateTime.utc_now()
      seconds = - 24 * 3600

      [
        [
          inserted_at: now
        ],
        [
          inserted_at: ~U[2020-01-01 00:00:00.123456Z],
          deleted_at: DateTime.add(now, 1 * seconds)
        ],
        [
          inserted_at: ~U[2020-02-01 00:00:00.123456Z],
          deleted_at: DateTime.add(now, 4 * seconds)
        ],
        [
          inserted_at: ~U[2020-04-01 00:00:00.123456Z],
          deleted_at: DateTime.add(now, 6 * seconds)
        ],
        [
          inserted_at: ~U[2020-04-01 00:00:00.123456Z],
          deleted_at: DateTime.add(now, 10 * seconds)
        ]
      ]
      |> Enum.with_index()
      |> Enum.map(fn {params, v} ->
        params |> Keyword.put(:data_structure_id, id) |> Keyword.put(:version, v)
      end)
      |> Enum.map(&insert(:data_structure_version, &1))

      assert {:ok, 2} = DataStructurePurge.purge_structure_versions(4)
      assert {:ok, 1} = DataStructurePurge.purge_structure_versions(2)
      assert {:ok, 0} = DataStructurePurge.purge_structure_versions(2)

      assert {:ok, 0} = DataStructurePurge.purge_structure_versions(nil)
      assert {:ok, 0} = DataStructurePurge.purge_structure_versions(:foo)
    end
  end
end
