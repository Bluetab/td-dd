defmodule TdCx.Sources.EventsTest do
  use TdDd.DataCase

  import Mox

  alias TdCx.Events

  setup_all do
    start_supervised!(TdCx.Search.IndexWorker)
    start_supervised!(TdDd.Search.Cluster)
    :ok
  end

  setup :set_mox_from_context
  setup :verify_on_exit!

  test "create_event/0 creates an event" do
    SearchHelpers.expect_bulk_index("/jobs/_doc/_bulk")
    %{id: job_id} = insert(:job)
    params = %{type: "init", message: "Message", job_id: job_id}
    claims = build(:cx_claims, role: "admin")
    assert {:ok, %{event: event, job_updated_at: {1, nil}}} = Events.create_event(params, claims)
    assert %{job_id: ^job_id, type: "init", message: "Message"} = event
  end
end
