defmodule TdDd.DataStructures.ValidationTest do
  use TdDd.DataStructureCase

  alias TdDd.DataStructures.Validation

  @moduletag sandbox: :shared

  setup do
    %{id: template_id, name: template_name} = template = CacheHelpers.insert_template()
    CacheHelpers.insert_structure_type(name: template_name, template_id: template_id)

    start_supervised!(TdDd.Search.StructureEnricher)
    [template: template]
  end

  describe "validator/1" do
    test "returns an empty content validator if structure has no type" do
      structure = insert(:structure_note)
      validator = Validation.validator(structure)
      assert is_function(validator, 2)
      assert validator.(:content, nil) == []
      assert validator.(:content, %{}) == []

      assert validator.(:content, %{"foo" => %{"value" => "bar", "origin" => "user"}}) == [
               content: "missing_type"
             ]
    end

    test "returns a validator that returns error if template is missing" do
      %{data_structure: structure} = insert(:data_structure_version, type: "missing")
      structure_note = insert(:structure_note, data_structure: structure)
      validator = Validation.validator(structure_note)
      assert is_function(validator, 2)

      assert validator.(:content, nil) == [
               content: {"invalid template", [reason: :template_not_found]}
             ]

      assert validator.(:content, %{}) == [
               content: {"invalid template", [reason: :template_not_found]}
             ]
    end

    test "returns a validator that validates dynamic content", %{template: %{name: type}} do
      %{data_structure: structure} = insert(:data_structure_version, type: type)
      structure_note = insert(:structure_note, data_structure: structure)
      validator = Validation.validator(structure_note)
      assert is_function(validator, 2)

      assert [{:content, {"list: is invalid - string: can't be blank", _errors}}] =
               validator.(:content, %{"list" => %{"value" => "four", "origin" => "user"}})
    end
  end

  describe "has_ai_suggestion/1" do
    test "returns true if ai_suggestion fields are available" do
      template = %{
        id: System.unique_integer([:positive]),
        label: "suggestions_test",
        name: "suggestions_test",
        scope: "dd",
        content: [
          %{
            "name" => "Identifier Template",
            "fields" => [
              %{
                "cardinality" => "1",
                "description" => "field description",
                "label" => "suggestion_field",
                "name" => "suggestion_field",
                "type" => "string",
                "ai_suggestion" => true
              }
            ]
          }
        ]
      }

      %{id: template_id, name: template_name} = CacheHelpers.insert_template(template)
      CacheHelpers.insert_structure_type(name: template_name, template_id: template_id)
      %{data_structure: structure} = insert(:data_structure_version, type: template_name)
      insert(:structure_note, data_structure: structure)

      assert Validation.has_ai_suggestion(structure)
    end

    test "returns false if no ai_suggestion fields are available" do
      template = %{
        id: System.unique_integer([:positive]),
        label: "suggestions_test",
        name: "suggestions_test",
        scope: "dd",
        content: [
          %{
            "name" => "Identifier Template",
            "fields" => [
              %{
                "cardinality" => "1",
                "description" => "field description",
                "label" => "suggestion_field",
                "name" => "suggestion_field",
                "type" => "string"
              }
            ]
          }
        ]
      }

      %{id: template_id, name: template_name} = CacheHelpers.insert_template(template)
      CacheHelpers.insert_structure_type(name: template_name, template_id: template_id)
      %{data_structure: structure} = insert(:data_structure_version, type: template_name)
      insert(:structure_note, data_structure: structure)

      refute Validation.has_ai_suggestion(structure)
    end
  end
end
