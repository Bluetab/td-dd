defmodule TdDq.ExecutionsTest do
  use TdDq.DataCase

  alias TdCache.Redix
  alias TdCache.Redix.Stream
  alias TdCache.StructureCache
  alias TdDq.Executions

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

    test "preloads implementations, executions and rule results" do
      %{id: implementation_id} = insert(:implementation)
      %{id: id} = insert(:execution_group)

      %{id: execution_id, result_id: result_id} =
        insert(:execution,
          group_id: id,
          implementation_id: implementation_id,
          result: build(:rule_result)
        )

      assert %{implementations: [%{id: ^implementation_id}]} =
               Executions.get_group(%{"id" => id}, preload: :implementations)

      assert %{executions: [%{id: ^execution_id, result: %{id: ^result_id}}]} =
               Executions.get_group(%{"id" => id}, preload: [executions: :result])
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
      %{id: id1} = insert(:implementation)
      %{id: id2} = insert(:implementation)

      filters = %{"id" => [id1, id2]}

      params = %{
        "created_by_id" => 0,
        "filters" => filters,
        "executions" => [
          %{"implementation_id" => id1},
          %{"implementation_id" => id2}
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
                 %{"id" => _, "implementation_id" => ^id1},
                 %{"id" => _, "implementation_id" => ^id2}
               ],
               "filters" => ^filters
             } = Jason.decode!(payload)
    end
  end

  describe "list_executions/2" do
    setup do
      %{id: implementation_id} = implementation = insert(:implementation)
      %{id: group_id1} = g1 = insert(:execution_group)
      %{id: group_id2} = g2 = insert(:execution_group)

      e1 = insert(:execution, group_id: group_id1, implementation_id: implementation_id)

      %{result: result} =
        e2 =
        insert(:execution,
          group_id: group_id2,
          implementation_id: implementation_id,
          result: build(:rule_result)
        )

      structure_id =
        implementation
        |> Map.get(:dataset)
        |> List.first()
        |> Map.get(:structure)
        |> Map.get(:id)

      structure = %{
        id: structure_id,
        name: "name",
        external_id: "ext_id",
        group: "group",
        type: "type",
        path: ["foo", "bar"],
        updated_at: DateTime.utc_now(),
        metadata: %{"alias" => "source_alias"},
        system_id: 999
      }

      {:ok, _} = StructureCache.put(structure)

      on_exit(fn ->
        StructureCache.delete(structure.id)
      end)

      [
        implementation: implementation,
        groups: [g1, g2],
        executions: [e1, e2],
        result: result,
        structure: structure
      ]
    end

    test "list executions", %{executions: [%{id: id1}, %{id: id2}], result: %{id: result_id}} do
      assert [%{id: ^id1, result: nil}, %{id: ^id2, result: %{id: ^result_id}}] =
               Executions.list_executions(%{}, preload: [:result])
    end

    test "list executions filtered by group", %{
      groups: [_, %{id: group_id}],
      executions: [_, %{id: id}]
    } do
      assert [%{id: ^id}] = Executions.list_executions(%{group_id: group_id})
    end

    test "list executions filtered by status", %{
      implementation: %{id: implementation_id},
      executions: [%{id: id}, _]
    } do
      assert [%{id: ^id, result: nil, implementation: %{id: ^implementation_id}}] =
               Executions.list_executions(%{status: "PENDING"},
                 preload: [:implementation, :result]
               )
    end

    test "list executions filtered by source", %{
      executions: [%{id: id1}, %{id: id2}],
      structure: %{metadata: %{"alias" => source}}
    } do
      assert [] = Executions.list_executions(%{source: "foo"})
      assert [%{id: ^id1}, %{id: ^id2}] = Executions.list_executions(%{source: source})
      assert [%{id: ^id1}] = Executions.list_executions(%{source: source, status: "PENDING"})
    end

    test "list executions filtered by sources", %{
      executions: [%{id: id1}, %{id: id2}],
      structure: %{metadata: %{"alias" => source}}
    } do
      assert [%{id: ^id1}, %{id: ^id2}] = Executions.list_executions(%{sources: [source]})
    end
  end
end
