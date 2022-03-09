defmodule TdCx.Sources.JobsTest do
  use TdDd.DataCase

  import Mox

  alias TdCx.Jobs

  setup_all do
    start_supervised!(TdCx.Search.IndexWorker)
    start_supervised!(TdDd.Search.Cluster)
    :ok
  end

  setup :set_mox_from_context
  setup :verify_on_exit!

  test "create_job/1 with valid data creates a job" do
    SearchHelpers.expect_bulk_index("/jobs/_doc/_bulk")
    source = insert(:source)
    attrs = %{source_id: source.id, parameters: %{foo: "bar"}}
    assert {:ok, %{} = job} = Jobs.create_job(attrs)
    assert job.source_id == source.id
    assert %{foo: "bar"} = job.parameters
    refute is_nil(job.external_id)
  end

  test "get_job!/2 will get a job with its events" do
    job = insert(:job)
    event = insert(:event, job: job)

    assert %{id: id, events: events, external_id: external_id} =
             Jobs.get_job!(job.external_id, [:events])

    assert id == job.id
    assert external_id == job.external_id
    assert length(events) == 1
    assert Enum.any?(events, &(&1.id == event.id))
  end

  test "metrics/1 will get job last event" do
    ts = DateTime.utc_now()
    job = insert(:job)
    e1 = insert(:event, job: job, type: "init", inserted_at: DateTime.add(ts, -10))
    e2 = insert(:event, job: job, type: "end", inserted_at: ts)

    metrics = Jobs.metrics([e1, e2])
    assert metrics.status == e2.type
    assert metrics.start_date == e1.inserted_at
    assert metrics.end_date == e2.inserted_at
  end
end
