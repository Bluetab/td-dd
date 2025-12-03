defmodule TdCx.FormatTest do
  use TdDd.DataCase

  alias TdCx.Format

  describe "get_cached_content/2" do
    test "enriches content with template" do
      template =
        CacheHelpers.insert_template(
          name: "test_type",
          content: [
            %{
              "name" => "group",
              "fields" => [
                %{"name" => "field1", "type" => "string"}
              ]
            }
          ]
        )

      content = %{"field1" => "value1"}

      result = Format.get_cached_content(content, template.name)

      assert is_map(result)
    end

    test "returns content when template not found" do
      content = %{"field1" => "value1"}

      result = Format.get_cached_content(content, "non_existent_type")

      assert result == content
    end

    test "returns content when content is not a map" do
      result = Format.get_cached_content("string content", "test_type")

      assert result == "string content"
    end

    test "returns content when content is nil" do
      result = Format.get_cached_content(nil, "test_type")

      assert result == nil
    end

    test "returns content when content is a list" do
      content = ["item1", "item2"]

      result = Format.get_cached_content(content, "test_type")

      assert result == content
    end

    test "handles empty content map" do
      template =
        CacheHelpers.insert_template(
          name: "empty_type",
          content: []
        )

      result = Format.get_cached_content(%{}, template.name)

      assert result == %{}
    end
  end
end
