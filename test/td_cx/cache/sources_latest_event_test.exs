defmodule TdCx.Cache.SourcesLatestEventTest do
  use TdDd.DataCase

  alias TdCx.Cache.SourcesLatestEvent

  @moduletag sandbox: :shared

  setup do
    %{id: source_1_id} = source_1 = insert(:source)
    job_source_1 = insert(:job, source_id: source_1_id)
    source_1_event_1 = insert(:event, job: job_source_1)
    source_1_event_2 = insert(:event, job: job_source_1)

    %{id: source_2_id} = source_2 = insert(:source)
    # job with events
    job_source_2_1 = insert(:job, source_id: source_2_id)
    source_2_event_1 = insert(:event, job: job_source_2_1)
    source_2_event_2 = insert(:event, job: job_source_2_1)
    # job without events
    job_source_2_2 = insert(:job, source_id: source_2_id)

    %{id: deleted_source_id} =
      deleted_source = insert(:source, deleted_at: ~U[2007-08-31 01:39:00Z])

    job_deleted_source = insert(:job, source_id: deleted_source_id)
    deleted_source_event_1 = insert(:event, job: job_deleted_source)
    deleted_source_event_2 = insert(:event, job: job_deleted_source)

    source_without_events = insert(:source)

    start_supervised!(TdCx.Cache.SourcesLatestEvent)

    %{
      sources_events: [
        %{source: source_1, jobs: [job_source_1], events: [source_1_event_1, source_1_event_2]},
        %{
          source: source_2,
          jobs: [job_source_2_1, job_source_2_2],
          events: [source_2_event_1, source_2_event_2]
        },
        %{
          source: deleted_source,
          jobs: [job_deleted_source],
          events: [deleted_source_event_1, deleted_source_event_2]
        },
        %{source: source_without_events, jobs: [], events: []}
      ]
    }
  end

  test "init loads all sources and their latest events", %{sources_events: sources_events} do
    [
      %{source: %{id: source_1_id}, events: [_source_1_event_1, %{id: source_1_event_2_id}]},
      %{source: %{id: source_2_id}, events: [_source_2_event_1, %{id: source_2_event_2_id}]},
      %{source: %{id: deleted_source_id}, events: _events},
      %{source: %{id: source_without_events_id}, events: []}
    ] = sources_events

    state = SourcesLatestEvent.state()

    assert %{
             ^source_1_id => %{id: ^source_1_event_2_id},
             ^source_2_id => %{id: ^source_2_event_2_id},
             ^source_without_events_id => nil
           } = state

    refute Map.has_key?(state, deleted_source_id)
  end

  test "get cache source id latest event", %{sources_events: sources_events} do
    [
      %{source: %{id: source_1_id}, events: [_source_1_event_1, %{id: source_1_event_2_id}]},
      %{source: _source_2, events: _events},
      _deleted_source,
      _source_without_events
    ] = sources_events

    assert %{id: ^source_1_event_2_id} = SourcesLatestEvent.get(source_1_id)
  end

  test "refresh reloads latest event", %{sources_events: sources_events} do
    [
      %{
        source: %{id: source_1_id},
        jobs: [job_source_1],
        events: _events
      },
      %{
        source: %{id: source_2_id},
        events: [_source_2_event_1, %{id: source_2_event_2_id}]
      },
      _deleted_source,
      %{source: %{id: source_without_events_id}}
    ] = sources_events

    %{id: source_1_event_3_id} = source_1_event_3 = insert(:event, job: job_source_1)

    SourcesLatestEvent.refresh(source_1_id, source_1_event_3)

    assert %{
             ^source_1_id => %{id: ^source_1_event_3_id},
             ^source_2_id => %{id: ^source_2_event_2_id},
             ^source_without_events_id => nil
           } = SourcesLatestEvent.state()
  end

  test "delete source from cache", %{sources_events: sources_events} do
    [
      %{
        source: %{id: source_1_id},
        events: [_source_1_event_1, _source_1_event_2]
      },
      %{
        source: %{id: source_2_id},
        events: [_source_2_event_1, %{id: source_2_event_2_id}]
      },
      _deleted_source,
      %{source: %{id: source_without_events_id}}
    ] = sources_events

    SourcesLatestEvent.delete(source_1_id)

    state = SourcesLatestEvent.state()
    refute Map.has_key?(state, source_1_id)

    assert %{
             ^source_2_id => %{id: ^source_2_event_2_id},
             ^source_without_events_id => nil
           } = state
  end
end
