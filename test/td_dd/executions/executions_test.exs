defmodule TdDd.ExecutionsTest do
  use TdDd.DataCase

  alias TdCache.Redix
  alias TdCache.Redix.Stream
  alias TdDd.DataStructures.RelationTypes
  alias TdDd.Executions

  @moduletag sandbox: :shared
  @stream TdCache.Audit.stream()

  setup_all do
    on_exit(fn -> Redix.del!(@stream) end)
  end

  setup do
    start_supervised!(TdDd.Search.StructureEnricher)
    :ok
  end

  describe "get_profile_group/2" do
    test "returns a group by id" do
      %{id: id} = insert(:profile_execution_group)
      assert %{id: ^id} = Executions.get_profile_group(%{"id" => id})
    end

    test "preloads data_structure, executions and profile" do
      %{id: structure_id} = data_structure = insert(:data_structure)
      %{id: id} = profile_group = insert(:profile_execution_group)

      %{id: execution_id, profile_id: profile_id} =
        insert(:profile_execution,
          profile_group: profile_group,
          data_structure: data_structure,
          profile: build(:profile)
        )

      assert %{structures: [%{id: ^structure_id}]} =
               Executions.get_profile_group(%{"id" => id}, preload: :structures)

      assert %{executions: [%{id: ^execution_id, profile: %{id: ^profile_id}}]} =
               Executions.get_profile_group(%{"id" => id}, preload: [executions: :profile])
    end

    test "enriches latest data structure version" do
      data_structure = insert(:data_structure)

      %{id: version_id, name: name} =
        insert(:data_structure_version, data_structure: data_structure)

      %{id: id} = profile_group = insert(:profile_execution_group)

      %{id: execution_id, profile_id: profile_id} =
        insert(:profile_execution,
          profile_group: profile_group,
          data_structure: data_structure,
          profile: build(:profile)
        )

      assert %{
               executions: [
                 %{
                   id: ^execution_id,
                   profile: %{id: ^profile_id},
                   latest: %{name: ^name, id: ^version_id}
                 }
               ]
             } =
               Executions.get_profile_group(%{"id" => id},
                 preload: [executions: [:data_structure, :profile]],
                 enrich: [:latest]
               )
    end
  end

  describe "list_profile_groups/2" do
    test "lists all groups" do
      %{id: id} = insert(:profile_execution_group)
      assert [%{id: ^id}] = Executions.list_profile_groups()
    end

    test "filters by created_by_id" do
      insert(:profile_execution_group)
      %{id: id} = insert(:profile_execution_group, created_by_id: 123)
      assert [%{id: ^id}] = Executions.list_profile_groups(%{created_by_id: 123})
    end
  end

  describe "create_profile_group/1" do
    test "inserts a group and publishes an audit event" do
      %{id: id1} = insert(:data_structure)
      %{id: id2} = insert(:data_structure)

      params = %{
        "created_by_id" => 0,
        "executions" => [
          %{"data_structure_id" => id1},
          %{"data_structure_id" => id2}
        ]
      }

      assert {:ok, multi} = Executions.create_profile_group(params)
      assert %{profile_group: %{id: group_id}, audit: event_id} = multi
      assert {:ok, [event]} = Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      resource_id = "#{group_id}"

      assert %{
               event: "execution_group_created",
               resource_type: "profile_execution_group",
               resource_id: ^resource_id,
               payload: payload
             } = event

      assert %{
               "executions" => [
                 %{"id" => _, "data_structure_id" => ^id1},
                 %{"id" => _, "data_structure_id" => ^id2}
               ]
             } = Jason.decode!(payload)
    end

    test "inserts a group with default event" do
      %{id: id} = insert(:data_structure)

      params = %{
        "created_by_id" => 0,
        "executions" => [
          %{"data_structure_id" => id}
        ]
      }

      assert {:ok, %{profile_group: %{id: id}}} = Executions.create_profile_group(params)

      %{
        executions: [
          %{profile_events: []}
        ]
      } = Executions.get_profile_group(%{"id" => id}, preload: [executions: :profile_events])
    end

    test "inserts a group given the parent structure id" do
      %{id: father, data_structure_id: data_structure_id} =
        insert(:data_structure_version, class: "table", name: "table")

      %{id: child_1, data_structure_id: child_structure_1} =
        insert(:data_structure_version, class: "field", name: "field_1")

      %{id: child_2, data_structure_id: child_structure_2} =
        insert(:data_structure_version, class: "field", name: "field_2")

      insert(:data_structure_relation,
        parent_id: father,
        child_id: child_1,
        relation_type_id: RelationTypes.default_id!()
      )

      insert(:data_structure_relation,
        parent_id: father,
        child_id: child_2,
        relation_type_id: RelationTypes.default_id!()
      )

      params = %{created_by_id: 0, parent_structure_id: data_structure_id}

      assert {:ok, %{profile_group: %{id: group_id} = profile_group, audit: event_id}} =
               Executions.create_profile_group(params, chunk_every: 1)

      assert profile_group.created_by_id == params.created_by_id
      assert Enum.count(profile_group.executions) == 2
      assert Enum.find(profile_group.executions, &(&1.data_structure_id == child_structure_1))
      assert Enum.find(profile_group.executions, &(&1.data_structure_id == child_structure_2))

      assert {:ok, [event]} = Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      resource_id = "#{group_id}"

      assert %{
               event: "execution_group_created",
               resource_type: "profile_execution_group",
               resource_id: ^resource_id
             } = event
    end
  end

  describe "list_profile_executions/2" do
    setup do
      source = "foo"

      data_structure = insert(:data_structure, source: build(:source, external_id: source))

      g1 = insert(:profile_execution_group)
      g2 = insert(:profile_execution_group)

      e1 =
        insert(:profile_execution,
          profile_group: g1,
          data_structure: data_structure
        )

      %{profile: profile} =
        e2 =
        insert(:profile_execution,
          profile_group: g2,
          data_structure: data_structure,
          profile: build(:profile)
        )

      e3 =
        insert(:profile_execution,
          profile_group: build(:profile_execution_group),
          data_structure: build(:data_structure)
        )

      e4 =
        insert(:profile_execution,
          profile_events: [build(:profile_event), build(:profile_event, type: "STARTED")]
        )

      [
        data_structure: data_structure,
        groups: [g1, g2],
        executions: [e1, e2, e3, e4],
        profile: profile,
        source: source
      ]
    end

    test "list executions", %{
      executions: [%{id: id1}, %{id: id2}, %{id: id3}, %{id: id4}],
      profile: %{id: profile_id}
    } do
      assert [
               %{id: ^id1, profile: nil},
               %{id: ^id2, profile: %{id: ^profile_id}},
               %{id: ^id3},
               %{id: ^id4}
             ] = Executions.list_profile_executions(%{}, preload: [:profile])
    end

    test "list executions filtered by group", %{
      groups: [_, %{id: group_id}],
      executions: [_, %{id: id}, _, _]
    } do
      assert [%{id: ^id}] = Executions.list_profile_executions(%{profile_group_id: group_id})
    end

    test "list executions filtered by status", %{
      data_structure: %{id: data_structure_id},
      executions: [%{id: id1}, _, %{id: id3}, _]
    } do
      assert [
               %{id: ^id1, profile: nil, data_structure: %{id: ^data_structure_id}},
               %{id: ^id3, profile: nil}
             ] =
               Executions.list_profile_executions(%{status: "PENDING"},
                 preload: [:data_structure, :profile]
               )
    end

    test "list executions filtered by source", %{
      executions: [%{id: id1}, %{id: id2}, _, _],
      source: source
    } do
      assert [] = Executions.list_profile_executions(%{source: "bar"})
      assert [%{id: ^id1}, %{id: ^id2}] = Executions.list_profile_executions(%{source: source})

      assert [%{id: ^id1}] =
               Executions.list_profile_executions(%{source: source, status: "PENDING"})
    end

    test "list executions filtered by sources", %{
      executions: [%{id: id1}, %{id: id2}, _, _],
      source: source
    } do
      assert [%{id: ^id1}, %{id: ^id2}] = Executions.list_profile_executions(%{sources: [source]})
    end
  end

  describe "update_all/2" do
    setup do
      d = insert(:data_structure)
      insert(:profile_execution, profile: build(:profile), data_structure: d)
      e2 = insert(:profile_execution, profile: nil, data_structure: d)
      e3 = insert(:profile_execution, profile: nil, data_structure: d)
      insert(:profile_execution, profile: nil, data_structure: build(:data_structure))

      [data_structure: d, executions: [e2, e3]]
    end

    test "updates all executions which do not have profile", %{
      data_structure: data_structure,
      executions: [%{id: id1}, %{id: id2}]
    } do
      profile = insert(:profile)
      assert {2, [^id1, ^id2]} = Executions.update_all(data_structure.id, profile.id)
    end
  end
end
