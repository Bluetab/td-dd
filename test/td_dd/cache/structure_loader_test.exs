defmodule TdDd.Cache.StructureLoaderTest do
  use TdDd.DataCase

  import Mox

  alias TdCache.StructureCache
  alias TdDd.Cache.StructureLoader
  alias TdDd.DataStructures
  alias TdDd.DataStructures.DataStructure
  alias TdDd.DataStructures.Hierarchy
  alias TdDd.DataStructures.RelationTypes
  alias TdDd.Search.StructureEnricher

  setup_all :verify_on_exit!

  describe "StructureLoader.cache_structures/2" do
    setup do
      start_supervised!(StructureEnricher)
      :ok
    end

    @tag sandbox: :shared
    test "encodes and puts cache entries with path" do
      %{
        child: %{id: child_dsv_id, data_structure_id: id},
        parent: %{id: parent_dsv_id, data_structure_id: parent_id, name: parent_name}
      } = insert(:data_structure_relation, relation_type_id: RelationTypes.default_id!())

      on_exit(fn ->
        Enum.each([id, parent_id], &StructureCache.delete/1)
      end)

      Hierarchy.update_hierarchy([child_dsv_id, parent_dsv_id])

      assert %{ok: 2} =
               [id, parent_id]
               |> StructureLoader.cache_structures()
               |> Enum.frequencies_by(&elem(&1, 0))

      assert {:ok, %{path: [^parent_name]}} = StructureCache.get(id)
      assert {:ok, %{path: []}} = StructureCache.get(parent_id)
    end
  end

  describe "StructureLoader consume events" do
    setup do
      import Mox

      # Start structure enricher
      start_supervised!(StructureEnricher)

      # Stub cluster handler for IA/embeddings
      stub(MockClusterHandler, :call, fn
        :ai, TdAi.Indices, :exists_enabled?, [] -> {:ok, false}
        :ai, TdAi.Indices, :list, [enabled: true] -> {:ok, []}
        _group, _mod, _fun, _args -> {:ok, false}
      end)

      # Start StructureLoader and authorize the mock in its process
      pid = start_supervised!(StructureLoader)
      allow(MockClusterHandler, self(), pid)

      :ok
    end

    @tag sandbox: :shared
    test "process add_link event (DS ↔ BC) and updates last_change_at" do
      %{id: ds_id} = insert(:data_structure)
      %{id: bc_id} = CacheHelpers.insert_concept()

      [%DataStructure{last_change_at: nil}] =
        DataStructures.list_data_structures(ids: [ds_id])

      GenServer.call(
        StructureLoader,
        {:consume,
         [
           %{
             event: "add_link",
             source: "data_structure:#{ds_id}",
             target: "business_concept:#{bc_id}"
           }
         ]}
      )

      [%DataStructure{last_change_at: last_change_at}] =
        DataStructures.list_data_structures(ids: [ds_id])

      assert not is_nil(last_change_at)
    end

    @tag sandbox: :shared
    test "process add_link event (BC ↔ DS) and updates last_change_at" do
      %{id: ds_id} = insert(:data_structure)
      %{id: bc_id} = CacheHelpers.insert_concept()

      [%DataStructure{last_change_at: nil}] =
        DataStructures.list_data_structures(ids: [ds_id])

      GenServer.call(
        StructureLoader,
        {:consume,
         [
           %{
             event: "add_link",
             source: "business_concept:#{bc_id}",
             target: "data_structure:#{ds_id}"
           }
         ]}
      )

      [%DataStructure{last_change_at: last_change_at}] =
        DataStructures.list_data_structures(ids: [ds_id])

      assert not is_nil(last_change_at)
    end

    @tag sandbox: :shared
    test "process remove_link event (DS ↔ BC) and updates last_change_at" do
      %{id: ds_id} = insert(:data_structure)
      %{id: bc_id} = CacheHelpers.insert_concept()

      [%DataStructure{last_change_at: nil}] =
        DataStructures.list_data_structures(ids: [ds_id])

      GenServer.call(
        StructureLoader,
        {:consume,
         [
           %{
             event: "remove_link",
             source: "data_structure:#{ds_id}",
             target: "business_concept:#{bc_id}"
           }
         ]}
      )

      [%DataStructure{last_change_at: last_change_at}] =
        DataStructures.list_data_structures(ids: [ds_id])

      assert not is_nil(last_change_at)
    end

    @tag sandbox: :shared
    test "process remove_link event (BC ↔ DS) and updates last_change_at" do
      %{id: ds_id} = insert(:data_structure)
      %{id: bc_id} = CacheHelpers.insert_concept()

      [%DataStructure{last_change_at: nil}] =
        DataStructures.list_data_structures(ids: [ds_id])

      GenServer.call(
        StructureLoader,
        {:consume,
         [
           %{
             event: "remove_link",
             source: "business_concept:#{bc_id}",
             target: "data_structure:#{ds_id}"
           }
         ]}
      )

      [%DataStructure{last_change_at: last_change_at}] =
        DataStructures.list_data_structures(ids: [ds_id])

      assert not is_nil(last_change_at)
    end

    @tag sandbox: :shared
    test "update last_change_at in add_link (DS ↔ DS) event" do
      %{id: ds_id1} = insert(:data_structure)
      %{id: ds_id2} = insert(:data_structure)

      [%DataStructure{last_change_at: nil}] =
        DataStructures.list_data_structures(ids: [ds_id1])

      GenServer.call(
        StructureLoader,
        {:consume,
         [
           %{
             event: "add_link",
             source: "data_structure:#{ds_id1}",
             target: "data_structure:#{ds_id2}"
           }
         ]}
      )

      [%DataStructure{last_change_at: last_change_at}] =
        DataStructures.list_data_structures(ids: [ds_id1])

      assert not is_nil(last_change_at)
    end

    @tag sandbox: :shared
    test "don't update last_change_at with add_rule_implementation_link event" do
      %{id: ds_id} = insert(:data_structure)

      [%DataStructure{last_change_at: nil}] =
        DataStructures.list_data_structures(ids: [ds_id])

      GenServer.call(
        StructureLoader,
        {:consume,
         [
           %{
             event: "add_rule_implementation_link",
             structure_id: ds_id
           }
         ]}
      )

      [%DataStructure{last_change_at: last_change_at}] =
        DataStructures.list_data_structures(ids: [ds_id])

      assert is_nil(last_change_at)
    end

    @tag sandbox: :shared
    test "ignores unsupported events" do
      result =
        GenServer.call(
          StructureLoader,
          {:consume,
           [
             %{
               event: "unsupported_event",
               some_data: "test"
             }
           ]}
        )

      assert result == []
    end

    @tag sandbox: :shared
    test "filters non-data-structure events correctly" do
      %{id: bc_id1} = CacheHelpers.insert_concept()
      %{id: bc_id2} = CacheHelpers.insert_concept()

      result =
        GenServer.call(
          StructureLoader,
          {:consume,
           [
             %{
               event: "add_link",
               source: "business_concept:#{bc_id1}",
               target: "business_concept:#{bc_id2}"
             }
           ]}
        )

      assert result == []
    end
  end
end
