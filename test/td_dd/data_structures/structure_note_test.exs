defmodule TdDd.DataStructures.StructureNoteTest do
  use TdDd.DataCase

  alias Ecto.Changeset
  alias TdDd.DataStructures.StructureNote

  @moduletag sandbox: :shared
  @invalid_content %{"string" => nil, "list" => "four"}
  @valid_content %{"identifier" => "cero", "string" => "present", "list" => "one"}
  @unsafe "javascript:alert(document)"

  setup do
    template_name_without_identifier = "structure_note_test_template_without_identifier"
    template_name_with_identifier = "structure_note_test_template_with_identifier"
    identifier_name = "identifier"

    without_identifier = %{
      id: System.unique_integer([:positive]),
      name: template_name_with_identifier,
      label: "structure_note_test_template",
      scope: "dd",
      content: [
        %{
          "fields" => [
            %{
              "cardinality" => "1",
              "label" => "string_field_label",
              "name" => "string",
              "type" => "string",
              "values" => nil
            },
            %{
              "cardinality" => "1",
              "label" => "list_field_label",
              "name" => "list",
              "type" => "list",
              "values" => %{"fixed" => ["one", "two", "three"]}
            }
          ],
          "name" => "group"
        }
      ]
    }

    with_identifier = %{
      id: System.unique_integer([:positive]),
      name: template_name_without_identifier,
      label: "structure_note_test_template",
      scope: "dd",
      content: [
        %{
          "fields" => [
            %{
              "cardinality" => "1",
              "default" => "",
              "label" => "Identifier",
              "name" => identifier_name,
              "subscribable" => false,
              "type" => "string",
              "values" => nil,
              "widget" => "identifier"
            },
            %{
              "cardinality" => "1",
              "label" => "string_field_label",
              "name" => "string",
              "type" => "string",
              "values" => nil
            },
            %{
              "cardinality" => "1",
              "label" => "list_field_label",
              "name" => "list",
              "type" => "list",
              "values" => %{"fixed" => ["one", "two", "three"]}
            }
          ],
          "name" => "group"
        }
      ]
    }

    %{id: template_id_with_identifier, name: template_name_with_identifier} =
      template_with_identifier = CacheHelpers.insert_template(with_identifier)

    %{id: template_id_without_identifier, name: template_name_without_identifier} =
      _template_without_identifier = CacheHelpers.insert_template(without_identifier)

    CacheHelpers.insert_structure_type(
      name: template_name_without_identifier,
      template_id: template_id_without_identifier
    )

    CacheHelpers.insert_structure_type(
      name: template_name_with_identifier,
      template_id: template_id_with_identifier
    )

    start_supervised!(TdDd.Search.StructureEnricher)

    data_structure_without_identifier = insert(:data_structure)

    insert(:data_structure_version,
      data_structure: data_structure_without_identifier,
      type: template_name_without_identifier
    )

    data_structure_with_identifier = insert(:data_structure)

    insert(:data_structure_version,
      data_structure: data_structure_with_identifier,
      type: template_name_with_identifier
    )

    identifier_value = "00000000-0000-0000-0000-000000000000"

    structure_note =
      insert(:structure_note,
        data_structure: data_structure_without_identifier,
        df_content: %{"foo" => "old"}
      )

    structure_note_with_identifier =
      insert(
        :structure_note,
        data_structure:
          data_structure_with_identifier |> Repo.preload(current_version: :structure_type),
        df_content: %{"foo" => "old", identifier_name => identifier_value}
      )

    [
      structure_note: structure_note,
      structure_note_with_identifier: structure_note_with_identifier,
      identifier_name: identifier_name,
      identifier_value: identifier_value,
      template_with_identifier: template_with_identifier
    ]
  end

  describe "create_changeset/3" do
    test "puts a new identifier if the template has an identifier field", %{
      identifier_name: identifier_name,
      template_with_identifier: template_with_identifier
    } do
      data_structure = insert(:data_structure)

      insert(:data_structure_version,
        data_structure: data_structure,
        type: template_with_identifier.name
      )

      structure_note = insert(:structure_note, data_structure: data_structure)

      attrs = %{
        version: 1,
        status: "draft",
        df_content: %{"bar" => "bar"}
      }

      assert %Changeset{changes: changes} =
               StructureNote.create_changeset(
                 %StructureNote{},
                 data_structure
                 |> Repo.preload(current_version: :structure_type)
                 |> Map.put(:latest_note, structure_note),
                 attrs
               )

      assert %{df_content: new_content} = changes
      assert %{^identifier_name => _identifier} = new_content
    end
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

    test "merges dynamic content preserving existing field", %{
      structure_note: structure_note
    } do
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

    test "validates content is not unsafe", %{structure_note: structure_note} do
      params = %{"df_content" => %{"foo" => [@unsafe]}}

      assert %{valid?: false, errors: errors} =
               StructureNote.bulk_update_changeset(structure_note, params)

      assert errors[:df_content] == {"invalid content", []}
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
      assert {"list: is invalid - string: can't be blank", details} = errors[:df_content]
      assert {"can't be blank", [validation: :required]} = details[:string]
      assert {"is invalid", [validation: :inclusion, enum: _]} = details[:list]
    end

    test "validates valid content when template exists", %{structure_note: structure_note} do
      assert %Changeset{valid?: true} =
               StructureNote.changeset(structure_note, %{df_content: @valid_content})
    end

    test "validates content is not unsafe", %{structure_note: structure_note} do
      params = %{"df_content" => Map.put(@valid_content, "string", @unsafe)}

      assert %{valid?: false, errors: errors} = StructureNote.changeset(structure_note, params)

      assert errors[:df_content] == {"invalid content", []}
    end

    test "keeps an already present identifier (i.e., editing)", %{
      structure_note_with_identifier: structure_note_with_identifier,
      identifier_name: identifier_name,
      identifier_value: identifier_value
    } do
      assert %Changeset{changes: changes} =
               StructureNote.changeset(structure_note_with_identifier, %{
                 df_content: %{"text" => "some update"}
               })

      assert %{df_content: new_content} = changes
      assert %{^identifier_name => ^identifier_value} = new_content
    end

    test "keeps an already present identifier (i.e., editing) if extraneous identifier attr is passed",
         %{
           structure_note_with_identifier: structure_note_with_identifier,
           identifier_name: identifier_name,
           identifier_value: identifier_value
         } do
      assert %Changeset{changes: changes} =
               StructureNote.changeset(structure_note_with_identifier, %{
                 df_content: %{
                   "text" => "some update",
                   identifier_name => "11111111-1111-1111-1111-111111111111"
                 }
               })

      assert %{df_content: new_content} = changes
      assert %{^identifier_name => ^identifier_value} = new_content
    end

    test "puts a new identifier if the template has an identifier field", %{
      identifier_name: identifier_name,
      template_with_identifier: template_with_identifier
    } do
      data_structure = insert(:data_structure)

      insert(:data_structure_version,
        data_structure: data_structure,
        type: template_with_identifier.name
      )

      # Structure note has no identifier but its data_structure template does
      # This happens if identifier is added to template after data_structure creation
      # Test an update to the structure note in this state.
      structure_note =
        insert(
          :structure_note,
          data_structure: data_structure |> Repo.preload(current_version: :structure_type)
        )

      # Just to make sure factory does not add identifier
      refute match?(%{df_content: %{^identifier_name => _identifier}}, structure_note)

      attrs = %{
        version: 1,
        status: "draft",
        df_content: %{"bar" => "bar"}
      }

      assert %Changeset{changes: changes} =
               StructureNote.changeset(
                 structure_note,
                 attrs
               )

      assert %{df_content: new_content} = changes
      assert %{^identifier_name => _identifier} = new_content
    end
  end
end
