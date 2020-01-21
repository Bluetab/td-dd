defmodule TdCx.Sources.EventsTest do
  use TdCx.DataCase

  alias TdCx.Search.IndexWorker
  alias TdCx.Sources.Events

  @valid_attrs %{date: DateTime.utc_now(), type: "init", message: "Message"}

  setup_all do
    start_supervised(IndexWorker)
    :ok
  end

  describe "events" do
    alias TdCx.Sources.Events.Event

    test "create_event/0 creates an event" do
      job = insert(:job)
      attrs = Map.put(@valid_attrs, :job_id, job.id)

      assert {:ok, %Event{} = event} = Events.create_event(attrs)
      assert event.job_id == job.id
      assert event.date == @valid_attrs.date
      assert event.type == @valid_attrs.type
      assert event.message == @valid_attrs.message
    end
  end
end
