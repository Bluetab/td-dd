defmodule TdDd.ExecutionsTest do
  use TdDd.DataCase

  alias TdCache.Redix
  alias TdCache.Redix.Stream
  alias TdDd.Executions

  @stream TdCache.Audit.stream()

  setup_all do
    on_exit(fn ->
      Redix.del!(@stream)
    end)
  end

  describe "get_group/2" do
    test "returns a group by id" do
      %{id: id} = insert(:execution_group)
      assert %{id: ^id} = Executions.get_group(%{"id" => id})
    end

    test "preloads data_structure, executions and profile" do
      %{id: structure_id} = insert(:data_structure)
      %{id: id} = insert(:execution_group)

      %{id: execution_id, profile_id: profile_id} =
        insert(:execution,
          group_id: id,
          data_structure_id: structure_id,
          profile: build(:profile)
        )

      assert %{structures: [%{id: ^structure_id}]} =
               Executions.get_group(%{"id" => id}, preload: :structures)

      assert %{executions: [%{id: ^execution_id, profile: %{id: ^profile_id}}]} =
               Executions.get_group(%{"id" => id}, preload: [executions: :profile])
    end
  end

  describe "list_groups/2" do
    test "lists all groups" do
      %{id: id} = insert(:execution_group)
      assert [%{id: ^id}] = Executions.list_groups()
    end

    test "filters by created_by_id" do
      insert(:execution_group)
      %{id: id} = insert(:execution_group, created_by_id: 123)
      assert [%{id: ^id}] = Executions.list_groups(%{created_by_id: 123})
    end
  end

  describe "create_group/1" do
    test "inserts a group and publishes an audit event" do
      %{id: id1} = insert(:data_structure)
      %{id: id2} = insert(:data_structure)

      filters = %{"id" => [id1, id2]}

      params = %{
        "created_by_id" => 0,
        "filters" => filters,
        "executions" => [
          %{"data_structure_id" => id1},
          %{"data_structure_id" => id2}
        ]
      }

      assert {:ok, multi} = Executions.create_group(params)
      assert %{group: %{id: group_id}, audit: event_id} = multi
      assert {:ok, [event]} = Stream.range(:redix, @stream, event_id, event_id, transform: :range)

      resource_id = "#{group_id}"

      assert %{
               event: "execution_group_created",
               resource_type: "execution_group",
               resource_id: ^resource_id,
               payload: payload
             } = event

      assert %{
               "executions" => [
                 %{"id" => _, "data_structure_id" => ^id1},
                 %{"id" => _, "data_structure_id" => ^id2}
               ],
               "filters" => ^filters
             } = Jason.decode!(payload)
    end
  end

  describe "list_executions/2" do
    setup do
      source = "foo"

      %{id: data_structure_id} = data_structure = insert(:data_structure)

      insert(:data_structure_version,
        data_structure: data_structure,
        metadata: %{"alias" => source}
      )

      %{id: group_id1} = g1 = insert(:execution_group)
      %{id: group_id2} = g2 = insert(:execution_group)

      e1 = insert(:execution, group_id: group_id1, data_structure_id: data_structure_id)

      %{profile: profile} =
        e2 =
        insert(:execution,
          group_id: group_id2,
          data_structure_id: data_structure_id,
          profile: build(:profile)
        )

      [
        data_structure: data_structure,
        groups: [g1, g2],
        executions: [e1, e2],
        profile: profile,
        source: source
      ]
    end

    test "list executions", %{executions: [%{id: id1}, %{id: id2}], profile: %{id: profile_id}} do
      assert [%{id: ^id1, profile: nil}, %{id: ^id2, profile: %{id: ^profile_id}}] =
               Executions.list_executions(%{}, preload: [:profile])
    end

    test "list executions filtered by group", %{
      groups: [_, %{id: group_id}],
      executions: [_, %{id: id}]
    } do
      assert [%{id: ^id}] = Executions.list_executions(%{group_id: group_id})
    end

    test "list executions filtered by status", %{
      data_structure: %{id: data_structure_id},
      executions: [%{id: id}, _]
    } do
      assert [%{id: ^id, profile: nil, data_structure: %{id: ^data_structure_id}}] =
               Executions.list_executions(%{status: "PENDING"},
                 preload: [:data_structure, :profile]
               )
    end

    test "list executions filtered by source", %{
      executions: [%{id: id1}, %{id: id2}],
      source: source
    } do
      assert [] = Executions.list_executions(%{source: "bar"})
      assert [%{id: ^id1}, %{id: ^id2}] = Executions.list_executions(%{source: source})
      assert [%{id: ^id1}] = Executions.list_executions(%{source: source, status: "PENDING"})
    end

    test "list executions filtered by sources", %{
      executions: [%{id: id1}, %{id: id2}],
      source: source
    } do
      assert [%{id: ^id1}, %{id: ^id2}] = Executions.list_executions(%{sources: [source]})
    end
  end
end
