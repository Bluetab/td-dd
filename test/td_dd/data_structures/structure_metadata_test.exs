defmodule TdDd.DataStructures.StructureMetadataTest do
  use TdDd.DataCase

  alias TdDd.DataStructures.StructureMetadata
  alias TdDd.Repo

  describe "changeset/2" do
    test "should capture unique constraint" do
      %{id: id} = insert(:data_structure)
      insert(:structure_metadata, data_structure_id: id, version: 123)

      params = params_for(:structure_metadata, data_structure_id: id, version: 123)

      assert {:error, %{errors: errors}} =
               params
               |> StructureMetadata.changeset()
               |> Repo.insert()

      assert {_,
              [
                constraint: :unique,
                constraint_name: "structure_metadata_data_structure_id_version_index"
              ]} = errors[:data_structure_id]
    end
  end
end
