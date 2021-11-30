defmodule TdDd.Lineage.LineageEventsTest do
  use TdDd.DataCase

  alias TdDd.Lineage.LineageEvent
  alias TdDd.Lineage.LineageEvents
  alias TdDd.Repo

  describe "LineageEvents.last_event_by_hash/1" do

    setup do
      [
        graph_hash: "wCVEPfaagsLqiogagnq4MlI2IMsuVtKOxHZaD0Xl82s=",
        before_timeout: DateTime.add(
          DateTime.utc_now(),
          -(TdDd.Lineage.timeout() - 5000), # 5 seconds enough time to finish tests
          :millisecond
        ),
        after_timeout: DateTime.add(
          DateTime.utc_now(),
          -(TdDd.Lineage.timeout() + 5000),
          :millisecond
        )
      ]
    end

    test "check_timeout does not modify COMPLETED status",
    %{graph_hash: graph_hash, before_timeout: before_timeout} do
      insert(
        :lineage_event,
        %{
          graph_hash: graph_hash,
          status: "COMPLETED",
          inserted_at: before_timeout
        }
      )
      assert %LineageEvent{status: "COMPLETED"} = LineageEvents.last_event_by_hash(graph_hash)
    end

    test "check_timeout does not modify FAILED status",
    %{graph_hash: graph_hash, before_timeout: before_timeout} do
      insert(
        :lineage_event,
        %{
          graph_hash: graph_hash,
          status: "FAILED",
          inserted_at: before_timeout
        }
      )
      assert %LineageEvent{status: "FAILED"} = LineageEvents.last_event_by_hash(graph_hash)
    end

    test "check_timeout does not modify TIMED_OUT status",
    %{graph_hash: graph_hash, before_timeout: before_timeout} do
      insert(
        :lineage_event,
        %{
          graph_hash: graph_hash,
          status: "TIMED_OUT",
          inserted_at: before_timeout
        }
      )
      assert %LineageEvent{status: "TIMED_OUT"} = LineageEvents.last_event_by_hash(graph_hash)
    end

    test "check_timeout returns ALREADY_STARTED status if timeout has not passed",
    %{graph_hash: graph_hash, before_timeout: before_timeout} do
      insert(
        :lineage_event,
        %{
          graph_hash: graph_hash,
          status: "STARTED",
          inserted_at: before_timeout
        }
      )
      assert %LineageEvent{status: "ALREADY_STARTED"} = LineageEvents.last_event_by_hash(graph_hash)
    end

    test "check_timeout returns TIMED_OUT status if timeout has passed",
    %{graph_hash: graph_hash, after_timeout: after_timeout} do
      insert(
        :lineage_event,
        %{
          graph_hash: graph_hash,
          status: "STARTED",
          inserted_at: after_timeout
        }
      )
      assert %LineageEvent{status: "TIMED_OUT"} = LineageEvents.last_event_by_hash(graph_hash)
    end
  end
end
