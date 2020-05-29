defmodule TdDd.DataStructures.ContentTest do
  use TdDd.DataStructureCase

  alias TdCache.TemplateCache
  alias TdDd.DataStructures.Content

  describe "merge/2" do
    test "returns nil if content is nil" do
      assert Content.merge(nil, %{foo: "foo"}) == nil
    end

    test "returns content if current_content is nil" do
      assert Content.merge(%{foo: "foo"}, nil) == %{foo: "foo"}
    end

    test "merges content with current_content, retaining new values" do
      assert Content.merge(%{foo: "new"}, %{foo: "old", bar: "bar"}) == %{foo: "new", bar: "bar"}
    end
  end

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
      validator = Content.validator(structure)
      assert is_function(validator, 2)
      assert validator.(:content, nil) == []
      assert validator.(:content, %{}) == []
      assert validator.(:content, %{"foo" => "bar"}) == [content: :missing_type]
    end

    test "returns a validator that returns error if template is missing" do
      %{data_structure: structure} = insert(:data_structure_version, type: "missing")
      validator = Content.validator(structure)
      assert is_function(validator, 2)
      assert validator.(:content, nil) == [content: {"invalid template", [reason: :template_not_found]}]
      assert validator.(:content, %{}) == [content: {"invalid template", [reason: :template_not_found]}]
    end

    test "returns a validator that validates dynamic content", %{template: %{name: type}} do
      %{data_structure: structure} = insert(:data_structure_version, type: type)
      validator = Content.validator(structure)
      assert is_function(validator, 2)
      assert [{:content, {"invalid content", _errors}}] = validator.(:content, %{"list" => "four"})
    end
  end
end
