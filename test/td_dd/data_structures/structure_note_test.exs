defmodule TdDd.DataStructures.StructureNoteTest do
  use TdDd.DataCase

  alias Ecto.Changeset
  alias TdCache.TemplateCache
  alias TdDd.DataStructures.StructureNote

  @moduletag sandbox: :shared
  @invalid_content %{"string" => nil, "list" => "four"}
  @valid_content %{"string" => "present", "list" => "one"}
  @template_name "structure_note_test_template"

  setup do
    %{id: template_id, name: template_name} = template = build(:template, name: @template_name)

    {:ok, _} = TemplateCache.put(template, publish: false)
    CacheHelpers.insert_structure_type(name: template_name, template_id: template_id)
    on_exit(fn -> TemplateCache.delete(template_id) end)

    start_supervised!(TdDd.Search.StructureEnricher)

    data_structure = insert(:data_structure)
    insert(:data_structure_version, data_structure: data_structure, type: @template_name)

    structure_note =
      insert(:structure_note, data_structure: data_structure, df_content: %{"foo" => "old"})

    [structure_note: structure_note]
  end

  describe "bulk_update_changeset/2" do
    test "validates invalid content when template exists", %{structure_note: structure_note} do
      assert %Changeset{valid?: false, errors: errors} =
               StructureNote.bulk_update_changeset(structure_note, %{df_content: @invalid_content})

      assert length(errors) == 1
      assert {"invalid_content", details} = errors[:df_content]
      assert {"can't be blank", [validation: :required]} = details[:string]
      assert {"is invalid", [validation: :inclusion, enum: _]} = details[:list]
    end

    test "merges dynamic content replacing existing field", %{structure_note: structure_note} do
      assert %Changeset{changes: changes} =
               StructureNote.bulk_update_changeset(structure_note, %{
                 df_content: %{"bar" => "bar", "foo" => "new"}
               })

      assert %{df_content: new_content} = changes
      assert new_content == %{"bar" => "bar", "foo" => "new"}
    end

    test "merges dynamic content preserving existing field", %{structure_note: structure_note} do
      assert %Changeset{changes: changes} =
               StructureNote.bulk_update_changeset(structure_note, %{
                 df_content: %{"bar" => "bar"}
               })

      assert %{df_content: new_content} = changes
      assert new_content == %{"bar" => "bar", "foo" => "old"}
    end

    test "does not replaces existing content with nil", %{structure_note: structure_note} do
      assert %Changeset{changes: changes} =
               StructureNote.bulk_update_changeset(structure_note, %{df_content: nil})

      assert %{} == changes
    end

    test "validates content when template is missing" do
      data_structure = insert(:data_structure)
      insert(:data_structure_version, data_structure: data_structure, type: "missing_type")
      structure_note = insert(:structure_note, data_structure: data_structure)

      assert %Changeset{valid?: false, errors: errors} =
               StructureNote.bulk_update_changeset(structure_note, %{
                 df_content: %{"foo" => "bar"}
               })

      assert length(errors) == 1
      assert {"invalid_template", [reason: :template_not_found]} = errors[:df_content]
    end

    test "identifies unchanged dynamic content (existing field value)", %{
      structure_note: structure_note
    } do
      assert %Changeset{changes: changes} =
               StructureNote.bulk_update_changeset(structure_note, %{
                 df_content: %{"foo" => "old"}
               })

      refute Map.has_key?(changes, :df_content)
    end

    test "identifies unchanged dynamic content (new content empty)", %{
      structure_note: structure_note
    } do
      assert %Changeset{changes: changes} =
               StructureNote.bulk_update_changeset(structure_note, %{df_content: %{}})

      refute Map.has_key?(changes, :df_content)
    end

    test "validates valid content when template exists", %{structure_note: structure_note} do
      assert %Changeset{valid?: true} =
               StructureNote.bulk_update_changeset(structure_note, %{df_content: @valid_content})
    end
  end

  describe "changeset/2" do
    test "replaces dynamic content with new content 1", %{structure_note: structure_note} do
      assert %Changeset{changes: changes} =
               StructureNote.changeset(structure_note, %{
                 df_content: %{"bar" => "bar", "foo" => "new"}
               })

      assert %{df_content: new_content} = changes
      assert new_content == %{"bar" => "bar", "foo" => "new"}
    end

    test "replaces dynamic content with new content 2", %{structure_note: structure_note} do
      assert %Changeset{changes: changes} =
               StructureNote.changeset(structure_note, %{
                 df_content: %{"bar" => "bar"}
               })

      assert %{df_content: new_content} = changes
      assert new_content == %{"bar" => "bar"}
    end

    test "identifies unchanged dynamic content (new content identical)", %{
      structure_note: structure_note
    } do
      assert %Changeset{changes: changes} =
               StructureNote.changeset(structure_note, %{
                 df_content: %{"foo" => "old"},
                 last_change_by: 123
               })

      refute Map.has_key?(changes, :df_content)
      refute Map.has_key?(changes, :last_change_by)
    end

    test "replaces existing content with empty map", %{structure_note: structure_note} do
      assert %Changeset{changes: changes} =
               StructureNote.changeset(structure_note, %{df_content: %{}})

      assert %{df_content: new_content} = changes
      assert new_content == %{}
    end

    test "replaces existing content with nil", %{structure_note: structure_note} do
      assert %Changeset{changes: changes} =
               StructureNote.changeset(structure_note, %{df_content: nil})

      assert %{} == changes
    end

    test "validates content when template is missing" do
      data_structure = insert(:data_structure)
      insert(:data_structure_version, data_structure: data_structure, type: "missing_type")
      structure_note = insert(:structure_note, data_structure: data_structure)

      assert %Changeset{valid?: false, errors: errors} =
               StructureNote.changeset(structure_note, %{df_content: %{"foo" => "bar"}})

      assert length(errors) == 1
      assert {"invalid template", [reason: :template_not_found]} = errors[:df_content]
    end

    test "validates invalid content when template exists", %{structure_note: structure_note} do
      assert %Changeset{valid?: false, errors: errors} =
               StructureNote.changeset(structure_note, %{df_content: @invalid_content})

      assert length(errors) == 1
      assert {"invalid content", details} = errors[:df_content]
      assert {"can't be blank", [validation: :required]} = details[:string]
      assert {"is invalid", [validation: :inclusion, enum: _]} = details[:list]
    end

    test "validates valid content when template exists", %{structure_note: structure_note} do
      assert %Changeset{valid?: true} =
               StructureNote.changeset(structure_note, %{df_content: @valid_content})
    end
  end
end
