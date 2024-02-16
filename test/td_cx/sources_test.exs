defmodule TdCx.SourcesTest do
  use TdDd.DataCase

  alias TdCx.Cache.SourcesLatestEvent
  alias TdCx.Sources
  alias TdCx.Sources.Source

  @moduletag sandbox: :shared

  @valid_attrs %{
    "config" => %{"a" => "1"},
    "external_id" => "some external_id",
    "secrets_key" => "some secrets_key",
    "type" => "template_type",
    "active" => true
  }
  @update_attrs %{"config" => %{"a" => "2"}, "active" => false}
  @invalid_attrs %{"config" => 2, "external_id" => nil, "secrets_key" => nil, "type" => nil}
  @template %{
    name: "template_type",
    label: "template_type",
    scope: "cx",
    content: [
      %{
        "name" => "New Group 1",
        "fields" => [
          %{
            "name" => "a",
            "type" => "string",
            "label" => "a",
            "widget" => "string",
            "cardinality" => "1"
          }
        ]
      }
    ]
  }

  setup do
    start_supervised!(TdCx.Cache.SourcesLatestEvent)
    [template: CacheHelpers.insert_template(@template)]
  end

  describe "Sources.get_source/1" do
    test "returns nil if params is nil" do
      assert Sources.get_source(nil) == nil
    end

    test "gets source by content alias if exists" do
      insert(:source)
      insert(:source, config: %{alias: "foo"})
      %{id: id, config: config} = insert(:source, config: %{"alias" => "bar"})
      assert %{id: ^id, config: ^config} = Sources.get_source(%{alias: "bar"})
    end
  end

  describe "sources" do
    test "list_sources/0 returns all sources" do
      source = source_fixture()
      assert Sources.list_sources() == [source]
    end

    test "list_sources/1 with deleted false returns non deleted sources" do
      source = source_fixture()
      _s2 = source_fixture(%{"deleted_at" => "2018-11-14 09:31:07Z"})
      assert Sources.list_sources(deleted: false) == [source]
      assert length(Sources.list_sources()) == 2
    end

    test "list_sources_by_source_type/1 returns only sources of a type" do
      %{name: type1} = CacheHelpers.insert_template(scope: "cx", content: [])
      %{name: type2} = CacheHelpers.insert_template(scope: "cx", content: [])

      src1 = insert(:source, external_id: "ext1", type: type1, secrets_key: "s", config: %{})
      src2 = insert(:source, external_id: "ext2", type: type2, secrets_key: "s", config: %{})

      assert length(Sources.list_sources()) == 2
      assert [^src1] = Sources.list_sources_by_source_type(type1)
      assert [^src2] = Sources.list_sources_by_source_type(type2)
    end

    test "list_sources_by_source_type/1 returns only active sources" do
      %{name: type} = CacheHelpers.insert_template(content: [], scope: "cx")

      src1 = insert(:source, external_id: "ext1", type: type, secrets_key: "s", config: %{})

      insert(:source,
        external_id: "ext2",
        type: type,
        secrets_key: "s",
        config: %{},
        active: false
      )

      assert length(Sources.list_sources()) == 2
      assert [^src1] = Sources.list_sources_by_source_type(type)
    end

    test "get_source!/1 returns the source with given id" do
      source = source_fixture()
      assert Sources.get_source!(source.external_id) == source
    end

    test "get_source!/2 with jobs option with get source with its jobs" do
      %{id: source_id, external_id: external_id} = source = source_fixture()
      %{id: job_id} = insert(:job, source: source)

      assert %Source{id: ^source_id, jobs: jobs} =
               Sources.get_source!(external_id: external_id, preload: :jobs)

      assert [%{id: ^job_id}] = jobs
    end

    test "create_source/1 with valid data creates a source" do
      assert {:ok, %Source{} = source} = Sources.create_source(@valid_attrs)
      assert source.config == %{"a" => "1"}
      assert source.external_id == "some external_id"
      # assert source.secrets_key == "some secrets_key"
      assert source.type == "template_type"
    end

    test "create_source/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Sources.create_source(@invalid_attrs)
    end

    test "update_source/2 with valid data updates the source" do
      source = source_fixture()
      assert {:ok, %Source{} = source} = Sources.update_source(source, @update_attrs)
      assert source.config == %{"a" => "2"}
    end

    test "update_source/2 with invalid data returns error changeset" do
      source = source_fixture()
      assert {:error, %Ecto.Changeset{}} = Sources.update_source(source, @invalid_attrs)
      assert source == Sources.get_source!(source.external_id)
    end

    test "delete_source/1 with related jobs logically deletes the source" do
      %{id: source_id} = source = insert(:source)
      job = insert(:job, source_id: source_id)
      event = insert(:event, job: job)

      # Manually insert latest event into cache
      SourcesLatestEvent.refresh(source_id, event)

      assert %{
               source_id => event
             } == SourcesLatestEvent.state()

      assert {:ok, %Source{deleted_at: _}} = Sources.delete_source(source)
      assert %{} == SourcesLatestEvent.state()
    end

    test "delete_source/1 without related jobs deletes the source" do
      source = source_fixture()
      assert {:ok, %Source{}} = Sources.delete_source(source)
      assert_raise Ecto.NoResultsError, fn -> Sources.get_source!(source.external_id) end
    end

    test "change_source/1 returns a source changeset" do
      source = source_fixture()
      assert %Ecto.Changeset{} = Sources.change_source(source)
    end

    test "create_or_update_source/1 with valid data creates a source or updates it if deleted" do
      attrs = Map.put(@valid_attrs, "external_id", "ex1")
      assert {:ok, %Source{} = source} = Sources.create_or_update_source(attrs)
      assert source.config == Map.get(attrs, "config")
      assert source.external_id == Map.get(attrs, "external_id")
      assert source.secrets_key == Map.get(attrs, "secrets_key")
      assert source.type == Map.get(attrs, "type")
      attrs = Map.merge(attrs, @update_attrs)

      assert {:error, %Ecto.Changeset{errors: [external_id: {"has already been taken", _}]}} =
               Sources.create_or_update_source(attrs)

      {:ok, %Source{}} = Sources.update_source(source, %{deleted_at: DateTime.utc_now()})
      assert {:ok, %Source{} = source} = Sources.create_or_update_source(attrs)
      assert source.config == Map.get(attrs, "config")
      assert source.external_id == Map.get(attrs, "external_id")
      # Empty secrets in config
      assert source.secrets_key == nil
      assert source.type == Map.get(attrs, "type")
    end

    test "job_types/1 with valid and invalid data" do
      source = insert(:source, config: %{"job_types" => ["catalog"]})
      assert ["catalog"] = Sources.job_types(source)

      source = insert(:source, config: %{"a" => "1"})
      assert [] = Sources.job_types(source)

      source = insert(:source, config: %{"job_types" => nil})
      assert [] = Sources.job_types(source)
    end
  end

  describe "Source.get_aliases/1" do
    test "returns an empty list if the source_id has no aliases" do
      %{id: source_id} = insert(:source, config: %{})
      assert Sources.get_aliases(source_id) == []
    end

    test "obtains the alias of a source specified by id" do
      %{id: source_id} = insert(:source, config: %{"alias" => "foo"})
      assert Sources.get_aliases(source_id) == ["foo"]
    end

    test "obtains the aliases of a source specified by id" do
      %{id: source_id} = insert(:source, config: %{"aliases" => ["foo", "bar"]})
      assert Sources.get_aliases(source_id) == ["foo", "bar"]
    end
  end

  describe "Sources.query_sources/1" do
    test "returns a list of sources" do
      insert(:source)
      insert(:source, config: %{alias: "foo"})

      %{id: id, config: config} =
        insert(:source, config: %{"alias" => "bar", "job_types" => ["profile"]})

      assert [%{id: ^id, config: ^config}] =
               Sources.query_sources(%{alias: "bar", job_types: "profile"})

      %{id: id, config: config} = insert(:source, config: %{"aliases" => ["foo"]})

      assert [%{id: ^id, config: ^config}] = Sources.query_sources(%{aliases: "foo"})

      assert [] = Sources.query_sources(%{alias: "baz"})
    end
  end

  describe "sources with latest events" do
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
      insert(:job, source_id: source_2_id)

      %{id: deleted_source_id} =
        deleted_source = insert(:source, deleted_at: ~U[2007-08-31 01:39:00Z])

      job_deleted_source = insert(:job, source_id: deleted_source_id)
      deleted_source_event_1 = insert(:event, job: job_deleted_source)
      deleted_source_event_2 = insert(:event, job: job_deleted_source)

      source_without_events = insert(:source)

      %{
        sources_events: [
          %{source: source_1, events: [source_1_event_1, source_1_event_2]},
          %{source: source_2, events: [source_2_event_1, source_2_event_2]},
          %{source: deleted_source, events: [deleted_source_event_1, deleted_source_event_2]},
          %{source: source_without_events, events: []}
        ]
      }
    end

    test "returns a list of sources with their latests events", %{sources_events: sources_events} do
      [
        %{source: %{id: source_1_id}, events: [_source_1_event_1, %{id: source_1_event_2_id}]},
        %{source: %{id: source_2_id}, events: [_source_2_event_1, %{id: source_2_event_2_id}]},
        %{
          source: %{id: deleted_source_id},
          events: [_source_3_event_1, %{id: deleted_source_event_2_id}]
        },
        %{source: %{id: source_without_events_id}, events: []}
      ] = sources_events

      assert [
               %{
                 id: ^source_1_id,
                 events: [%{id: ^source_1_event_2_id}]
               },
               %{
                 id: ^source_2_id,
                 events: [%{id: ^source_2_event_2_id}]
               },
               %{
                 id: ^deleted_source_id,
                 events: [%{id: ^deleted_source_event_2_id}]
               },
               %{
                 id: ^source_without_events_id,
                 events: []
               }
             ] = Sources.query_sources(%{with_latest_event: true})
    end

    test "returns a list of sources and their latest events as a map, excluding logically deleted",
         %{sources_events: sources_events} do
      [
        %{source: %{id: source_1_id}, events: [_source_1_event_1, %{id: source_1_event_2_id}]},
        %{source: %{id: source_2_id}, events: [_source_2_event_1, %{id: source_2_event_2_id}]},
        %{source: %{id: deleted_source_id}, events: _events},
        %{source: %{id: source_without_events_id}, events: []}
      ] = sources_events

      sources = Sources.list_sources_with_latest_event()

      assert %{
               ^source_1_id => %{id: ^source_1_event_2_id},
               ^source_2_id => %{id: ^source_2_event_2_id},
               ^source_without_events_id => nil
             } = sources

      refute Map.has_key?(sources, deleted_source_id)
    end
  end

  defp source_fixture(attrs \\ %{}) do
    {:ok, source} =
      attrs
      |> Enum.into(@valid_attrs)
      |> Sources.create_source()

    source
  end
end
