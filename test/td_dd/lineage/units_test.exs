defmodule TdDd.Lineage.UnitsTest do
  use TdDd.DataCase

  alias TdDd.Lineage.Units
  alias TdDd.Lineage.Units.Unit
  alias TdDd.Repo

  setup do
    events = Enum.map(1..5, fn id -> build(:unit_event, event: "Event #{id}") end)
    [unit: insert(:unit, events: events)]
  end

  describe "Units.get_by/1" do
    test "returns error tuple if not found" do
      assert {:error, :not_found} = Units.get_by(name: "foo")
    end

    test "returns unit by name", %{unit: %{id: id, name: name}} do
      assert {:ok, %{id: ^id}} = Units.get_by(name: name)
    end

    test "includes latest event as status", %{unit: %{name: name, events: events}} do
      assert {:ok, %{status: status}} = Units.get_by(name: name, status: true)
      assert status == Enum.max_by(events, & &1.inserted_at, DateTime)
    end

    test "filters deleted units" do
      assert %{name: name} = insert(:unit, deleted_at: DateTime.utc_now())
      assert {:error, :not_found} = Units.get_by(name: name, deleted: false)
    end

    test "performs dynamic preloads", %{unit: %{name: name}} do
      assert {:ok, %{edges: [], nodes: []}} = Units.get_by(name: name, preload: [:nodes, :edges])
    end
  end

  describe "Units.list_units/1" do
    test "includes latest event as status", %{unit: %{name: name, events: events}} do
      assert [%{name: ^name, status: status}] = Units.list_units(status: true)
      assert status == Enum.max_by(events, & &1.inserted_at, DateTime)
    end
  end

  describe "Units.insert_event/3" do
    test "inserts a valid event with a timestamp", %{unit: unit} do
      ts = DateTime.utc_now()

      assert {:ok, %Units.Event{inserted_at: inserted_at}} =
               Units.insert_event(unit, "LoadStarted", %{foo: "bar"})

      assert DateTime.compare(ts, inserted_at) == :lt
    end
  end

  describe "Units.last_updated/0" do
    test "returns the most recent LoadSucceeded event timestamp" do
      ts = DateTime.utc_now()
      insert(:unit_event, event: "LoadSucceeded", inserted_at: ts, unit: build(:unit))
      assert Units.last_updated() == ts
    end

    test "returns the most recent Deleted event timestamp" do
      ts = DateTime.utc_now()
      insert(:unit_event, event: "Deleted", inserted_at: ts, unit: build(:unit))
      assert Units.last_updated() == ts
    end
  end

  describe "Units.list_nodes/1" do
    test "returns the list of nodes by type" do
      %{type: type} = node = insert(:node)
      assert Units.list_nodes(type: type) == [node]
    end

    test "returns the list of nodes by external id" do
      %{external_id: external_id} = node = insert(:node)
      assert Units.list_nodes(external_id: external_id) == [node]
      assert Units.list_nodes(external_id: [external_id]) == [node]
    end

    test "filters deleted nodes" do
      %{type: type} = insert(:node, deleted_at: DateTime.utc_now())
      assert Units.list_nodes(type: type) == []
    end
  end

  describe "Units.list_domain_ids/" do
    test "returns empty units have not domains" do
      insert(:unit)
      assert [] = Units.list_domain_ids()
    end

    test "return units taxonomy" do
      %{id: parent_domain_id} = CacheHelpers.insert_domain()
      %{id: domain_id} = CacheHelpers.insert_domain(%{parent_id: parent_domain_id})
      %{id: sibling_domain_id} = CacheHelpers.insert_domain(%{parent_id: parent_domain_id})
      insert(:unit)
      insert(:unit, domain_id: domain_id)
      insert(:unit, domain_id: sibling_domain_id)

      assert [_, _] = domain_ids = Units.list_domain_ids()
      assert domain_id in domain_ids
      assert sibling_domain_id in domain_ids
    end
  end

  describe "Units.list_relations/1" do
    test "returns the list of edges by type", %{unit: unit} do
      %{id: id, type: type} = insert(:edge, start: build(:node), end: build(:node), unit: unit)
      assert [%{id: ^id}] = Units.list_relations(type: type)
    end

    test "filters edges pertaining to deleted nodes", %{unit: unit} do
      start = insert(:node, deleted_at: DateTime.utc_now())
      %{type: type} = insert(:edge, start: start, end: build(:node), unit: unit)
      assert Units.list_relations(type: type) == []
    end
  end

  describe "Units.link_nodes/1" do
    test "links nodes to data structures by external_id", %{unit: unit} do
      assert %{id: system_id} = insert(:system)

      assert %{id: _structure_id, external_id: external_id} =
               insert(:data_structure, system_id: system_id)

      assert %{external_id: ^external_id} = insert(:node, units: [unit], external_id: external_id)
      assert {:ok, 1} = Units.link_nodes(unit_id: unit.id)
    end
  end

  describe "Units.replace_unit/1" do
    test "inserts a unit if it doesn't exist" do
      ts = DateTime.utc_now()
      assert {:ok, multi} = Units.replace_unit(%{"name" => "foo"})
      assert %{create: %Units.Unit{inserted_at: inserted_at}} = multi
      assert DateTime.compare(ts, inserted_at) == :lt
    end

    test "refreshes a unit if it exists" do
      assert %{id: prev_id, name: name} = insert(:unit)
      assert {:ok, multi} = Units.replace_unit(%{"name" => name})
      assert %{create: %Units.Unit{name: ^name, id: id}} = multi
      refute id == prev_id
    end
  end

  describe "Units.update_unit/2" do
    test "updates unit when attributes changes" do
      %{id: id, name: name, deleted_at: deleted_at} = unit = insert(:unit)

      assert {:ok, %Units.Unit{id: ^id, name: ^name, deleted_at: ^deleted_at}} =
               Units.update_unit(unit, %{name: name})

      assert {:ok, %Units.Unit{id: ^id, name: "new_name", deleted_at: ^deleted_at}} =
               Units.update_unit(unit, %{name: "new_name"})

      assert {:ok, %Units.Unit{id: ^id, domain_id: 1}} = Units.update_unit(unit, %{domain_id: 1})
    end
  end

  describe "delete_unit/2" do
    setup do
      assert %{id: _unit_id} = unit = insert(:unit)
      assert %{id: start_id} = node1 = insert(:node, units: [unit])
      assert %{id: end_id} = node2 = insert(:node, units: [unit])

      assert %{id: _edge_id} =
               edge = insert(:edge, start_id: start_id, end_id: end_id, unit: unit)

      [unit: unit, nodes: [node1, node2], edges: [edge]]
    end

    test "performs physical deletion of a unit and it's nodes", %{
      unit: %{id: unit_id} = unit,
      nodes: nodes,
      edges: edges
    } do
      assert {:ok, multi} = Units.delete_unit(unit, logical: false)

      assert %{
               delete_nodes: delete_nodes,
               delete_unit: delete_unit,
               delete_unit_nodes: delete_unit_nodes
             } = multi

      assert {2, deleted_ids} = delete_nodes
      assert %Units.Unit{id: ^unit_id, deleted_at: nil} = delete_unit
      assert {2, _} = delete_unit_nodes

      assert MapSet.new(nodes, & &1.id) == MapSet.new(deleted_ids)

      refute Repo.get(Units.Unit, unit_id)

      for %{id: id} <- nodes do
        refute Repo.get(Units.Node, id)
      end

      for %{id: id} <- edges do
        refute Repo.get(Units.Edge, id)
      end
    end

    test "performs logical deletion of a unit and it's nodes", %{
      unit: %{id: unit_id} = unit,
      nodes: nodes,
      edges: edges
    } do
      assert {:ok, multi} = Units.delete_unit(unit)

      assert %{
               delete_nodes: delete_nodes,
               delete_unit: delete_unit,
               delete_unit_nodes: delete_unit_nodes
             } = multi

      assert {2, deleted_ids} = delete_nodes
      assert %Units.Unit{id: ^unit_id, deleted_at: deleted_at} = delete_unit
      assert {2, _} = delete_unit_nodes
      assert deleted_at

      assert Repo.get(Units.Unit, unit_id)
      assert MapSet.new(nodes, & &1.id) == MapSet.new(deleted_ids)

      for %{id: id} <- nodes do
        assert Repo.get(Units.Node, id)
      end

      for %{id: id} <- edges do
        assert Repo.get(Units.Edge, id)
      end
    end

    test "does not delete nodes which belong to other units", %{
      unit: %{id: unit_id} = unit,
      nodes: [n1 | nodes],
      edges: edges
    } do
      _another_unit = insert(:unit, nodes: [n1])

      assert {:ok, multi} = Units.delete_unit(unit, logical: false)

      assert %{
               delete_nodes: delete_nodes,
               delete_unit: delete_unit,
               delete_unit_nodes: delete_unit_nodes
             } = multi

      assert {1, deleted_ids} = delete_nodes
      assert %Units.Unit{id: ^unit_id, deleted_at: _deleted_at} = delete_unit
      assert {2, _} = delete_unit_nodes

      refute Enum.member?(deleted_ids, n1.id)

      assert %{deleted_at: nil} = Repo.get(Units.Node, n1.id)

      for %{id: id} <- nodes do
        refute Repo.get(Units.Node, id)
      end

      for %{id: id} <- edges do
        refute Repo.get(Units.Edge, id)
      end
    end
  end

  describe "delete_async/2" do
    test "deletes a unit asynchronously", %{unit: unit} do
      assert {:ok, %Oban.Job{} = job} = Units.delete_async(unit, %{"logical" => "false"})
      assert job.state == "available"

      assert_enqueued(
        worker: TdDd.Lineage.Units.Workers.DeleteUnit,
        args: %{"unit_id" => unit.id, "logical" => "false"}
      )
    end
  end

  describe "get/1" do
    test "returns a unit by id", %{unit: %{id: id}} do
      assert %Unit{id: ^id} = Units.get(id)
    end

    test "returns nil if the unit is not found" do
      refute Units.get(123)
    end
  end
end
