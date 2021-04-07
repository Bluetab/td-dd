defmodule TdCx.Sources.JobsTest do
  use TdDd.DataCase

  alias TdCx.Jobs
  alias TdCx.Search.IndexWorker

  setup_all do
    start_supervised(IndexWorker)
    :ok
  end

  describe "jobs" do
    alias TdCx.Jobs.Job

    test "create_job/1 with valid data creates a job" do
      source = insert(:source)
      attrs = %{source_id: source.id, parameters: %{foo: "bar"}}
      assert {:ok, %Job{} = job} = Jobs.create_job(attrs)
      assert job.source_id == source.id
      assert %{foo: "bar"} = job.parameters
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
      e1 = insert(:event, job: fixture, type: "init")
      :timer.sleep(1)
      e2 = insert(:event, job: fixture, type: "end")

      metrics = Jobs.metrics([e1, e2])
      assert metrics.status == e2.type
      assert metrics.start_date == e1.inserted_at
      assert metrics.end_date == e2.inserted_at
    end
  end
end
