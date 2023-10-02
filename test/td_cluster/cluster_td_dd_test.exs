defmodule TdCluster.ClusterTdDdTest do
  use ExUnit.Case
  use TdDd.DataCase

  alias TdCluster.Cluster
  alias TdDd.DataStructures.RelationTypes
  alias TdDd.ReferenceData.Dataset

  @moduletag sandbox: :shared

  setup do
    start_supervised!(TdDd.Search.StructureEnricher)
    :ok
  end

  describe "test Cluster.TdDd functions" do
    test "get_reference_dataset/1" do
      %{id: id, name: name, headers: headers} = insert(:reference_dataset)

      assert {:ok,
              %Dataset{
                id: ^id,
                name: ^name,
                headers: ^headers
              }} = Cluster.TdDd.get_reference_dataset(id)
    end

    test "get_latest_structure_version/1" do
      %{id: id, data_structure_id: data_structure_id} = insert(:data_structure_version)

      %{id: child_id} =
        insert(:data_structure_version, class: "field", metadata: %{"data_type_class" => "string"})

      relation_type_id = RelationTypes.default_id!()

      insert(:data_structure_relation,
        parent_id: id,
        child_id: child_id,
        relation_type_id: relation_type_id
      )

      assert {:ok,
              %{
                id: ^id,
                data_fields: [
                  %{
                    id: ^child_id,
                    class: "field",
                    metadata: %{"data_type_class" => "string"}
                  }
                ]
              }} = Cluster.TdDd.get_latest_structure_version(data_structure_id)
    end
  end
end
