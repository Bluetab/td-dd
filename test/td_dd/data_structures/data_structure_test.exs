defmodule TdDd.DataStructures.DataStructureTest do
  use TdDd.DataCase

  alias Ecto.Changeset
  alias TdCache.StructureTypeCache
  alias TdCache.TemplateCache
  alias TdDd.DataStructures.DataStructure

  @invalid_content %{"string" => nil, "list" => "four"}
  @valid_content %{"string" => "present", "list" => "one"}

  setup_all do
    %{id: template_id, name: type} = template = build(:template)
    TemplateCache.put(template, publish: false)

    %{id: structure_type_id} =
      structure_type = build(:data_structure_type, structure_type: type, template_id: template_id)

    {:ok, _} = StructureTypeCache.put(structure_type)

    on_exit(fn ->
      TemplateCache.delete(template_id)
      StructureTypeCache.delete(structure_type_id)
    end)

    [type: type]
  end

  setup %{type: type} do
    %{data_structure: structure} =
      insert(:data_structure_version,
        type: type,
        data_structure: build(:data_structure, df_content: %{"foo" => "old"})
      )

    [structure: structure]
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

    test "validates content when template is missing" do
      %{data_structure: data_structure} = insert(:data_structure_version, type: "missing_type")

      assert %Changeset{valid?: false, errors: errors} =
               DataStructure.changeset(data_structure, %{df_content: %{"foo" => "bar"}})

      assert length(errors) == 1
      assert {"invalid template", [reason: :template_not_found]} = errors[:df_content]
    end

    test "validates invalid content when template exists", %{structure: structure} do
      assert %Changeset{valid?: false, errors: errors} =
               DataStructure.changeset(structure, %{df_content: @invalid_content})

      assert length(errors) == 1
      assert {"invalid content", details} = errors[:df_content]
      assert {"can't be blank", [validation: :required]} = details[:string]
      assert {"is invalid", [validation: :inclusion, enum: _]} = details[:list]
    end

    test "validates valid content when template exists", %{structure: structure} do
      assert %Changeset{valid?: true} =
               DataStructure.changeset(structure, %{df_content: @valid_content})
    end
  end

  describe "merge_changeset/2" do
    test "merges dynamic content replacing existing field", %{structure: structure} do
      assert %Changeset{changes: changes} =
               DataStructure.merge_changeset(structure, %{
                 df_content: %{"bar" => "bar", "foo" => "new"},
                 last_change_by: 123
               })

      assert %{df_content: new_content} = changes
      assert new_content == %{"bar" => "bar", "foo" => "new"}
    end

    test "merges dynamic content preserving existing field", %{structure: structure} do
      assert %Changeset{changes: changes} =
               DataStructure.merge_changeset(structure, %{
                 df_content: %{"bar" => "bar"},
                 last_change_by: 123
               })

      assert %{df_content: new_content} = changes
      assert new_content == %{"bar" => "bar", "foo" => "old"}
    end

    test "identifies unchanged dynamic content (existing field value)", %{structure: structure} do
      assert %Changeset{changes: changes} =
               DataStructure.merge_changeset(structure, %{
                 df_content: %{"foo" => "old"},
                 last_changed_by: 123
               })

      refute Map.has_key?(changes, :df_content)
      refute Map.has_key?(changes, :last_changed_by)
    end

    test "identifies unchanged dynamic content (new content empty)", %{structure: structure} do
      assert %Changeset{changes: changes} =
               DataStructure.merge_changeset(structure, %{df_content: %{}, last_change_by: 123})

      refute Map.has_key?(changes, :df_content)
      refute Map.has_key?(changes, :last_changed_by)
    end

    test "replaces existing content with nil", %{structure: structure} do
      assert %Changeset{changes: changes} =
               DataStructure.merge_changeset(structure, %{df_content: nil})

      assert %{df_content: nil} = changes
    end

    test "validates content when template is missing" do
      %{data_structure: structure} = insert(:data_structure_version, type: "missing_type")

      assert %Changeset{valid?: false, errors: errors} =
               DataStructure.merge_changeset(structure, %{df_content: %{"foo" => "bar"}})

      assert length(errors) == 1
      assert {"invalid template", [reason: :template_not_found]} = errors[:df_content]
    end

    test "validates invalid content when template exists", %{structure: structure} do
      assert %Changeset{valid?: false, errors: errors} =
               DataStructure.merge_changeset(structure, %{df_content: @invalid_content})

      assert length(errors) == 1
      assert {"invalid content", details} = errors[:df_content]
      assert {"can't be blank", [validation: :required]} = details[:string]
      assert {"is invalid", [validation: :inclusion, enum: _]} = details[:list]
    end

    test "validates valid content when template exists", %{structure: structure} do
      assert %Changeset{valid?: true} =
               DataStructure.merge_changeset(structure, %{df_content: @valid_content})
    end
  end

  describe "update_changeset/2" do
    test "replaces dynamic content with new content 1", %{structure: structure} do
      assert %Changeset{changes: changes} =
               DataStructure.update_changeset(structure, %{
                 df_content: %{"bar" => "bar", "foo" => "new"}
               })

      assert %{df_content: new_content} = changes
      assert new_content == %{"bar" => "bar", "foo" => "new"}
    end

    test "replaces dynamic content with new content 2", %{structure: structure} do
      assert %Changeset{changes: changes} =
               DataStructure.update_changeset(structure, %{
                 df_content: %{"bar" => "bar"}
               })

      assert %{df_content: new_content} = changes
      assert new_content == %{"bar" => "bar"}
    end

    test "identifies unchanged dynamic content (new content identical)", %{structure: structure} do
      assert %Changeset{changes: changes} =
               DataStructure.update_changeset(structure, %{
                 df_content: %{"foo" => "old"},
                 last_change_by: 123
               })

      refute Map.has_key?(changes, :df_content)
      refute Map.has_key?(changes, :last_change_by)
    end

    test "replaces existing content with empty map", %{structure: structure} do
      assert %Changeset{changes: changes} =
               DataStructure.update_changeset(structure, %{df_content: %{}})

      assert %{df_content: new_content} = changes
      assert new_content == %{}
    end

    test "replaces existing content with nil", %{structure: structure} do
      assert %Changeset{changes: changes} =
               DataStructure.update_changeset(structure, %{df_content: nil})

      assert %{df_content: new_content} = changes
      assert new_content == nil
    end

    test "validates content when template is missing" do
      %{data_structure: structure} = insert(:data_structure_version, type: "missing_type")

      assert %Changeset{valid?: false, errors: errors} =
               DataStructure.update_changeset(structure, %{df_content: %{"foo" => "bar"}})

      assert length(errors) == 1
      assert {"invalid template", [reason: :template_not_found]} = errors[:df_content]
    end

    test "validates invalid content when template exists", %{structure: structure} do
      assert %Changeset{valid?: false, errors: errors} =
               DataStructure.update_changeset(structure, %{df_content: @invalid_content})

      assert length(errors) == 1
      assert {"invalid content", details} = errors[:df_content]
      assert {"can't be blank", [validation: :required]} = details[:string]
      assert {"is invalid", [validation: :inclusion, enum: _]} = details[:list]
    end

    test "validates valid content when template exists", %{structure: structure} do
      assert %Changeset{valid?: true} =
               DataStructure.update_changeset(structure, %{df_content: @valid_content})
    end
  end
end
