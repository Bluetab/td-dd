defmodule TdCx.Sources.EventsTest do
  use TdDd.DataCase

  alias TdCx.Events
  alias TdCx.Search.IndexWorker

  @valid_attrs %{type: "init", message: "Message"}

  setup_all do
    start_supervised(IndexWorker)
    :ok
  end

  describe "events" do
    alias TdCx.Events.Event

    test "create_event/0 creates an event" do
      job = insert(:job)
      attrs = Map.put(@valid_attrs, :job_id, job.id)

      assert {:ok, %Event{} = event} = Events.create_event(attrs)
      assert event.job_id == job.id
      assert event.type == @valid_attrs.type
      assert event.message == @valid_attrs.message
    end
  end
end
