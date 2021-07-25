defmodule TdDd.DataStructures.HistoryManagerTest do
  use TdDd.DataStructureCase

  alias TdDd.DataStructures.HistoryManager

  setup do
    0..9
    |> Enum.map(&days_ago/1)
    |> Enum.each(fn ts ->
      insert(:data_structure_version, deleted_at: ts)
      insert(:structure_metadata, deleted_at: ts)
    end)
  end

  describe "purge_history/0" do
    test "deletes data structure versions and structure metadata" do
      assert {:ok, %{} = multi} = HistoryManager.purge_history()
      assert %{data_structure_versions: {5, _}, structure_metadata: {5, _}} = multi
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

    test "deletes data structure versions with deleted_at before n days ago" do
      assert {:ok, %{} = multi} = HistoryManager.purge_history(8)
      assert %{data_structure_versions: {2, _}} = multi
      assert {:ok, %{} = multi} = HistoryManager.purge_history(8)
      assert %{data_structure_versions: {0, _}} = multi
    end

    test "deletes structure metadata with deleted_at before n days ago" do
      assert {:ok, %{} = multi} = HistoryManager.purge_history(8)
      assert %{structure_metadata: {2, _}} = multi
      assert {:ok, %{} = multi} = HistoryManager.purge_history(8)
      assert %{structure_metadata: {0, _}} = multi
    end
  end

  defp days_ago(days) do
    DateTime.add(DateTime.utc_now(), -days * 60 * 60 * 24)
  end
end
