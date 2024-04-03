defmodule TdCx.Sources.EventsTest do
  use TdDd.DataCase

  import Mox

  alias TdCore.Search.IndexWorkerMock
  alias TdCx.Cache.SourcesLatestEvent
  alias TdCx.Events

  @moduletag sandbox: :shared

  setup do
    start_supervised!(TdCx.Cache.SourcesLatestEvent)

    IndexWorkerMock.clear()

    :ok
  end

  setup :set_mox_from_context
  setup :verify_on_exit!

  test "create_event/0 creates an event" do
    IndexWorkerMock.clear()
    %{id: source_id} = insert(:source)
    %{id: job_id} = insert(:job, source_id: source_id)
    params = %{type: "init", message: "Message", job_id: job_id}
    claims = build(:claims, role: "admin")
    assert {:ok, %{event: event, job_updated_at: {1, nil}}} = Events.create_event(params, claims)
    assert %{job_id: ^job_id, type: "init", message: "Message"} = event
    assert [{:reindex, :jobs, [_]}] = IndexWorkerMock.calls()

    assert %{
             ^source_id => ^event
           } = SourcesLatestEvent.state()
  end
end
