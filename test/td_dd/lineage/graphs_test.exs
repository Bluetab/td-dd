defmodule TdDd.Lineage.GraphsTest do
  use TdDd.DataCase

  alias TdDd.Lineage.Graphs

  describe "hash" do
    test "find by hash, non-stale graph" do
      #  graph updated_at is older than last lineage load
      insert(:unit_event,
        event: "LoadSucceeded",
        inserted_at: ~U[2007-08-31 01:39:00Z],
        unit: build(:unit)
      )

      graph = insert(:graph, hash: "1")

      assert graph == Graphs.find_by_hash("1")
    end

    test "find by hash, consider graph non-stale if no lineage load event is present" do
      graph = insert(:graph, hash: "1")
      assert graph == Graphs.find_by_hash("1")
    end

    test "find by hash returns nil for non-exixtent graph" do
      assert nil == Graphs.find_by_hash("1234")
    end

    test "find by hash returns nil if graph exists but it is stale" do
      unit = insert(:unit)
      # Inserting two lineage load events: one that makes graph stale and one
      # that does not, just to check only the latest one is selected
      insert(:unit_event,
        event: "LoadSucceeded",
        inserted_at: ~U[2001-01-03 00:00:00Z],
        unit: unit
      )

      insert(:unit_event,
        event: "LoadSucceeded",
        inserted_at: ~U[2001-01-01 00:00:00Z],
        unit: unit
      )

      insert(:graph, hash: "1", updated_at: ~U[2001-01-02 00:00:00Z])

      assert nil == Graphs.find_by_hash("1")
    end
  end
end
