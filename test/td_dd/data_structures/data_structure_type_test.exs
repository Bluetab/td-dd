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

    test "validates filters" do
      [%{name: f1} | _] =
        fields = [
          build(:metadata_field, data_structure_type: nil),
          build(:metadata_field, data_structure_type: nil)
        ]

      type = insert(:data_structure_type, metadata_fields: fields)

      assert %{errors: errors} = DataStructureType.changeset(type, %{"filters" => ["foo"]})
      assert {"has an invalid entry", [validation: :subset, enum: [^f1, _]]} = errors[:filters]

      assert %{valid?: true} = DataStructureType.changeset(type, %{"filters" => [f1]})
    end
  end
end
