defmodule TdCx.Sources.JobsTest do
  use TdDd.DataCase

  import Mox

  alias TdCore.Search.IndexWorkerMock
  alias TdCx.Jobs

  setup do
    IndexWorkerMock.clear()

    :ok
  end

  setup :set_mox_from_context
  setup :verify_on_exit!

  test "create_job/1 with valid data creates a job" do
    source = insert(:source)
    attrs = %{source_id: source.id, parameters: %{foo: "bar"}}
    assert {:ok, %{} = job} = Jobs.create_job(attrs)
    assert job.source_id == source.id
    assert %{foo: "bar"} = job.parameters
    refute is_nil(job.external_id)
    assert [{:reindex, :jobs, [_]}] = IndexWorkerMock.calls()
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
  end

  test "list_jobs/0 returns all jobs" do
    job1 = insert(:job)
    job2 = insert(:job)

    jobs = Jobs.list_jobs()

    assert length(jobs) >= 2
    assert Enum.any?(jobs, &(&1.id == job1.id))
    assert Enum.any?(jobs, &(&1.id == job2.id))
  end

  test "with_metrics/1 adds metrics from events" do
    ts = DateTime.utc_now()
    job = insert(:job)
    insert(:event, job: job, type: "SUCCEEDED", message: "Done", inserted_at: ts)

    job_with_events = Repo.preload(job, :events)

    result = Jobs.with_metrics(job_with_events)

    assert result.status == "SUCCEEDED"
    assert result.message == "Done"
  end

  test "with_metrics/1 returns job unchanged when events not preloaded" do
    job = insert(:job)

    result = Jobs.with_metrics(job)

    assert result == job
  end

  test "with_metrics/1 returns job unchanged when events is empty" do
    job = insert(:job)
    job_with_empty_events = Map.put(job, :events, [])

    result = Jobs.with_metrics(job_with_empty_events)

    assert result == job_with_empty_events
  end

  test "metrics/2 returns empty map for empty events" do
    assert Jobs.metrics([]) == %{}
  end

  test "metrics/2 with message returns status and message" do
    event = insert(:event, type: "FAILED", message: "Error occurred")

    metrics = Jobs.metrics([event])

    assert metrics.status == "FAILED"
    assert metrics.message == "Error occurred"
  end

  test "metrics/2 without message returns only status" do
    event = insert(:event, type: "SUCCEEDED", message: nil)

    metrics = Jobs.metrics([event])

    assert metrics.status == "SUCCEEDED"
    refute Map.has_key?(metrics, :message)
  end

  test "metrics/2 truncates long messages" do
    long_message = String.duplicate("a", 100)
    event = insert(:event, type: "FAILED", message: long_message)

    metrics = Jobs.metrics([event], max_length: 50)

    assert metrics.status == "FAILED"
    assert byte_size(metrics.message) == 50
  end

  test "metrics/2 does not truncate short messages" do
    event = insert(:event, type: "SUCCEEDED", message: "Short message")

    metrics = Jobs.metrics([event], max_length: 50)

    assert metrics.message == "Short message"
  end

  test "metrics/2 selects most recent event by inserted_at" do
    ts = DateTime.utc_now()
    job = insert(:job)
    e1 = insert(:event, job: job, type: "STARTED", inserted_at: DateTime.add(ts, -20))
    e2 = insert(:event, job: job, type: "PROCESSING", inserted_at: DateTime.add(ts, -10))
    e3 = insert(:event, job: job, type: "COMPLETED", inserted_at: ts)

    metrics = Jobs.metrics([e1, e2, e3])

    assert metrics.status == "COMPLETED"
  end
end
