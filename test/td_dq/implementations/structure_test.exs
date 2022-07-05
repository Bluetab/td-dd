defmodule TdDq.Implementations.StructureTest do
  use TdDd.DataCase

  alias TdDq.Implementations.Structure

  describe "changeset/2" do
    test "validates id is required for typeless structure" do
      params = %{}

      assert %{valid?: false, errors: errors} = Structure.changeset(params)
      assert {"can't be blank", [validation: :required]} = errors[:id]

      params = %{"id" => 123}
      assert %{valid?: true} = Structure.changeset(params)
    end

    test "validates name and parent_index are required for reference_dataset_field" do
      params = %{"type" => "reference_dataset_field"}

      assert %{valid?: false, errors: errors} = Structure.changeset(params)
      assert {"can't be blank", [validation: :required]} = errors[:name]
      assert {"can't be blank", [validation: :required]} = errors[:parent_index]

      params = %{"type" => "reference_dataset_field", "name" => "field_name", "parent_index" => 1}
      assert %{valid?: true} = Structure.changeset(params)
    end
  end
end
