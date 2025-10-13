defmodule TdDd.CacheConfigTest do
  use ExUnit.Case

  setup do
    original_audit_config = Application.get_env(:td_cache, :audit, [])
    original_event_stream_config = Application.get_env(:td_cache, :event_stream, [])

    on_exit(fn ->
      Application.put_env(:td_cache, :audit, original_audit_config)
      Application.put_env(:td_cache, :event_stream, original_event_stream_config)
    end)

    :ok
  end

  describe "td-cache configuration from environment variables" do
    test "reads REDIS_AUDIT_STREAM_MAXLEN from environment" do
      System.put_env("REDIS_AUDIT_STREAM_MAXLEN", "200")

      Application.put_env(:td_cache, :audit,
        service: "td_dd",
        stream: "audit:events",
        maxlen: System.get_env("REDIS_AUDIT_STREAM_MAXLEN", "100")
      )

      audit_config = Application.get_env(:td_cache, :audit)
      assert Keyword.get(audit_config, :maxlen) == "200"

      System.delete_env("REDIS_AUDIT_STREAM_MAXLEN")
    end

    test "reads REDIS_STREAM_MAXLEN from environment" do
      System.put_env("REDIS_STREAM_MAXLEN", "350")

      Application.put_env(:td_cache, :event_stream,
        maxlen: System.get_env("REDIS_STREAM_MAXLEN", "100"),
        streams: [
          [group: "dd", key: "data_structure:events", consumer: TdDd.Cache.StructureLoader],
          [group: "dd", key: "template:events", consumer: TdCore.Search.IndexWorker],
          [group: "dq", key: "business_concept:events", consumer: TdCore.Search.IndexWorker],
          [group: "dq", key: "domain:events", consumer: TdDq.Cache.DomainEventConsumer],
          [
            group: "dq",
            key: "implementation_ref:events",
            consumer: TdDq.Cache.ImplementationLoader
          ],
          [group: "dq", key: "template:events", consumer: TdCore.Search.IndexWorker]
        ]
      )

      event_stream_config = Application.get_env(:td_cache, :event_stream)
      assert Keyword.get(event_stream_config, :maxlen) == "350"

      System.delete_env("REDIS_STREAM_MAXLEN")
    end

    test "uses default values when environment variables are not set" do
      System.delete_env("REDIS_AUDIT_STREAM_MAXLEN")
      System.delete_env("REDIS_STREAM_MAXLEN")

      Application.put_env(:td_cache, :audit,
        service: "td_dd",
        stream: "audit:events",
        maxlen: System.get_env("REDIS_AUDIT_STREAM_MAXLEN", "100")
      )

      Application.put_env(:td_cache, :event_stream,
        maxlen: System.get_env("REDIS_STREAM_MAXLEN", "100"),
        streams: []
      )

      audit_config = Application.get_env(:td_cache, :audit)
      event_stream_config = Application.get_env(:td_cache, :event_stream)

      assert Keyword.get(audit_config, :maxlen) == "100"
      assert Keyword.get(event_stream_config, :maxlen) == "100"
    end

    test "configuration preserves existing stream consumers" do
      System.put_env("REDIS_STREAM_MAXLEN", "400")

      Application.put_env(:td_cache, :event_stream,
        consumer_id: "default",
        consumer_group: "dd",
        maxlen: System.get_env("REDIS_STREAM_MAXLEN", "100"),
        streams: [
          [group: "dd", key: "data_structure:events", consumer: TdDd.Cache.StructureLoader],
          [group: "dd", key: "template:events", consumer: TdCore.Search.IndexWorker],
          [group: "dq", key: "business_concept:events", consumer: TdCore.Search.IndexWorker]
        ]
      )

      event_stream_config = Application.get_env(:td_cache, :event_stream)

      assert Keyword.get(event_stream_config, :maxlen) == "400"
      assert Keyword.get(event_stream_config, :consumer_id) == "default"
      assert Keyword.get(event_stream_config, :consumer_group) == "dd"
      assert length(Keyword.get(event_stream_config, :streams)) == 3

      System.delete_env("REDIS_STREAM_MAXLEN")
    end
  end
end
