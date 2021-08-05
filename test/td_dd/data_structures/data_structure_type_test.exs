defmodule TdDd.DataStructures.DataStructureTypeTest do
  use TdDd.DataCase

  alias TdDd.DataStructures.DataStructureType

  describe "DataStructureType.changeset/2" do
    test "casts metadata_views association fields" do
      type = insert(:data_structure_type)

      assert %{valid?: true, changes: changes} =
               DataStructureType.changeset(type, %{
                 metadata_views: [
                   string_params_for(:metadata_view),
                   string_params_for(:metadata_view)
                 ]
               })

      assert [%{action: :replace}, %{action: :insert}, %{action: :insert}] =
               changes[:metadata_views]
    end
  end
end
