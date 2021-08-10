defmodule TdDd.DataStructures.DataStructureTest do
  use TdDd.DataCase

  alias Ecto.Changeset
  alias TdDd.DataStructures.DataStructure

  @moduletag sandbox: :shared

  setup do
    %{id: template_id, name: template_name} = template = CacheHelpers.insert_template()
    CacheHelpers.insert_structure_type(name: template_name, template_id: template_id)

    start_supervised!(TdDd.Search.StructureEnricher)

    %{data_structure: structure} =
      insert(:data_structure_version,
        type: template_name,
        data_structure: build(:data_structure)
      )

    [template: template, type: template_name, structure: structure]
  end

  describe "changeset/2" do
    test "validates required fields" do
      assert %Changeset{valid?: false, errors: errors} = DataStructure.changeset(%{})

      assert length(errors) == 3
      assert errors[:external_id] == {"can't be blank", [validation: :required]}
      assert errors[:last_change_by] == {"can't be blank", [validation: :required]}
      assert errors[:system_id] == {"can't be blank", [validation: :required]}
    end

    test "only casts last_change_by if other changes are present" do
      assert %Changeset{valid?: false, errors: errors, changes: changes} =
               DataStructure.changeset(%{last_change_by: 123, foo: "bar"})

      assert changes == %{}
      assert errors[:last_change_by] == {"can't be blank", [validation: :required]}

      assert %Changeset{valid?: false, changes: changes} =
               DataStructure.changeset(%{last_change_by: 123, external_id: "foo"})

      assert changes[:last_change_by] == 123
    end
  end
end
