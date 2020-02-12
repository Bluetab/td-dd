defmodule TdCx.Sources.JobsTest do
  use TdCx.DataCase

  alias TdCx.Search.IndexWorker
  alias TdCx.Sources.Jobs

  setup_all do
    start_supervised(IndexWorker)
    :ok
  end

  describe "jobs" do
    alias TdCx.Sources.Jobs.Job

    test "create_job/1 with valid data creates a job" do
      source = insert(:source)
      assert {:ok, %Job{} = job} = Jobs.create_job(%{source_id: source.id})
      assert job.source_id == source.id
      assert not is_nil(job.external_id)
    end

    test "get_job!/2 will get a job with its events" do
      fixture = insert(:job)
      event = insert(:event, job: fixture)

      assert %Job{id: id, events: events, external_id: external_id} =
               Jobs.get_job!(fixture.external_id, [:events])

      assert id == fixture.id
      assert external_id == fixture.external_id
      assert length(events) == 1
      assert Enum.any?(events, &(&1.id == event.id))
    end

    test "metrics/1 will get job last event" do
      fixture = insert(:job)
      d1 = DateTime.utc_now()
      d2 = DateTime.to_unix(d1, :millisecond) + 1
      d2 = elem(DateTime.from_unix(d2, :millisecond), 1)
      e1 = insert(:event, job: fixture, date: d1, type: "init")
      e2 = insert(:event, job: fixture, date: d2, type: "end")

      metrics = Jobs.metrics([e1, e2])
      assert metrics.status == e2.type
      assert metrics.start_date == e1.date
      assert metrics.end_date == e2.date
    end
  end
end
