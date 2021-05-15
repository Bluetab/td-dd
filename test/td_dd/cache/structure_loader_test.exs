defmodule TdDd.Cache.StructureLoaderTest do
  use TdDd.DataCase

  alias TdCache.StructureCache
  alias TdDd.Cache.StructureLoader
  alias TdDd.DataStructures.RelationTypes

  describe "StructureLoader.cache_structures/2" do
    setup do
      start_supervised!(TdDd.Search.StructureEnricher)
      :ok
    end

    @tag sandbox: :shared
    test "encodes and puts cache entries with path" do
      %{
        child: %{data_structure_id: id},
        parent: %{data_structure_id: parent_id, name: parent_name}
      } = insert(:data_structure_relation, relation_type_id: RelationTypes.default_id!())

      on_exit(fn ->
        Enum.each([id, parent_id], &StructureCache.delete/1)
      end)

      assert %{ok: 2} =
               [id, parent_id]
               |> StructureLoader.cache_structures()
               |> Enum.frequencies_by(&elem(&1, 0))

      assert {:ok, %{path: [^parent_name]}} = StructureCache.get(id)
      assert {:ok, %{path: []}} = StructureCache.get(parent_id)
    end
  end
end
