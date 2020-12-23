defmodule TdDq.ExecutionsTest do
  use TdDq.DataCase

  alias TdCache.Redix
  alias TdCache.Redix.Stream
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
      %{id: execution_id} = insert(:execution, group_id: id, implementation_id: implementation_id)
      %{id: result_id} = insert(:rule_result, execution_id: execution_id)

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
end
