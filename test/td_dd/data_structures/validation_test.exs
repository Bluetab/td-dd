defmodule TdDd.DataStructures.ValidationTest do
  use TdDd.DataStructureCase

  alias TdCache.TemplateCache
  alias TdDd.DataStructures.Validation

  describe "validator/1" do
    setup do
      %{id: template_id} = template = build(:template)
      TemplateCache.put(template, publish: false)

      on_exit(fn ->
        TemplateCache.delete(template_id)
      end)

      [template: template]
    end

    test "returns an empty content validator if structure has no type" do
      structure = build(:data_structure)
      validator = Validation.validator(structure)
      assert is_function(validator, 2)
      assert validator.(:content, nil) == []
      assert validator.(:content, %{}) == []
      assert validator.(:content, %{"foo" => "bar"}) == [content: :missing_type]
    end

    test "returns a validator that returns error if template is missing" do
      %{data_structure: structure} = insert(:data_structure_version, type: "missing")
      validator = Validation.validator(structure)
      assert is_function(validator, 2)
      assert validator.(:content, nil) == [content: {"invalid template", [reason: :template_not_found]}]
      assert validator.(:content, %{}) == [content: {"invalid template", [reason: :template_not_found]}]
    end

    test "returns a validator that validates dynamic content", %{template: %{name: type}} do
      %{data_structure: structure} = insert(:data_structure_version, type: type)
      validator = Validation.validator(structure)
      assert is_function(validator, 2)
      assert [{:content, {"invalid content", _errors}}] = validator.(:content, %{"list" => "four"})
    end
  end
end
