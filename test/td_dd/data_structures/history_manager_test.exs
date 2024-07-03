defmodule TdDd.DataStructures.HistoryManagerTest do
  use TdDd.DataStructureCase

  alias TdDd.DataStructures.HistoryManager

  setup do
    ds_active = insert(:data_structure)

    insert(:data_structure_version,
      name: "active_9_days",
      data_structure: ds_active,
      version: 0,
      deleted_at: days_ago(9)
    )

    insert(:data_structure_version,
      name: "active_6_days",
      data_structure: ds_active,
      version: 1,
      deleted_at: days_ago(6)
    )

    insert(:data_structure_version,
      name: "active_3_days",
      data_structure: ds_active,
      version: 2,
      deleted_at: days_ago(3)
    )

    insert(:data_structure_version,
      name: "active_0_days",
      data_structure: ds_active,
      version: 3
    )

    insert(:structure_metadata, data_structure: ds_active, version: 0, deleted_at: days_ago(9))
    insert(:structure_metadata, data_structure: ds_active, version: 1, deleted_at: days_ago(6))
    insert(:structure_metadata, data_structure: ds_active, version: 2, deleted_at: days_ago(3))
    insert(:structure_metadata, data_structure: ds_active, version: 3)

    ds_deleted = insert(:data_structure)

    insert(:data_structure_version,
      name: "deleted_9_days",
      data_structure: ds_deleted,
      version: 0,
      deleted_at: days_ago(9)
    )

    insert(:data_structure_version,
      name: "deleted_6_days",
      data_structure: ds_deleted,
      version: 1,
      deleted_at: days_ago(6)
    )

    insert(:structure_metadata, data_structure: ds_deleted, version: 0, deleted_at: days_ago(9))
    insert(:structure_metadata, data_structure: ds_deleted, version: 1, deleted_at: days_ago(6))

    ds_one_version = insert(:data_structure)

    insert(:data_structure_version,
      name: "one_version_9_days",
      data_structure: ds_one_version,
      version: 0,
      deleted_at: days_ago(9)
    )

    insert(:structure_metadata,
      data_structure: ds_one_version,
      version: 0,
      deleted_at: days_ago(9)
    )

    %{
      ds_active: ds_active,
      ds_deleted: ds_deleted,
      ds_one_version: ds_one_version
    }
  end

  describe "purge_history/0" do
    test "deletes data structure versions and structure metadata" do
      assert {:ok, %{} = multi} = HistoryManager.purge_history()
      assert %{data_structure_versions: {3, _}, structure_metadata: {3, _}} = multi
    end
  end

  describe "purge_history/1" do
    test "returns ok if days is nil" do
      assert HistoryManager.purge_history(nil) == :ok
    end

    test "raises if days is zero or negative" do
      for days <- [0, -4] do
        assert_raise FunctionClauseError, fn ->
          HistoryManager.purge_history(days)
        end
      end
    end

    test "returns a multi result if days is a positive integer" do
      assert {:ok, %{} = multi} = HistoryManager.purge_history(1)
      assert %{data_structure_versions: _, structure_metadata: _} = multi
    end

    test "deletes data structure versions and metadata versions with deleted_at before n days ago" do
      assert {:ok, %{} = multi} = HistoryManager.purge_history(8)
      assert %{data_structure_versions: {2, _}} = multi
      assert %{structure_metadata: {2, _}} = multi
      assert {:ok, %{} = multi} = HistoryManager.purge_history(8)
      assert %{data_structure_versions: {0, _}} = multi
      assert %{structure_metadata: {0, _}} = multi
    end
  end

  defp days_ago(days) do
    DateTime.add(DateTime.utc_now(), -days * 60 * 60 * 24)
  end
end
