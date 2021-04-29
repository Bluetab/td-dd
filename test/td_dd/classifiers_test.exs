defmodule TdDd.ClassifiersTest do
  use TdDd.DataCase

  alias TdDd.Classifiers
  alias TdDd.Classifiers.Classifier

  describe "Classifiers.create_classifier/1" do
    test "creates a classifier" do
      %{id: system_id} = insert(:system)

      params = %{
        "system_id" => system_id,
        "name" => "environment",
        "filters" => [
          %{"property" => "type", "values" => ["schema"]}
        ],
        "rules" => [
          %{"class" => "prod", "property" => "external_id", "regex" => "glue://.*"},
          %{
            "class" => "dev",
            "priority" => 10,
            "property" => "metadata.foo.bar",
            "values" => ["whatever", "whatever"]
          }
        ]
      }

      assert {:ok, %Classifier{} = classifier} = Classifiers.create_classifier(params)

      assert %{
               filters: [filter],
               rules: [r1, r2],
               name: "environment"
             } = classifier

      assert %{property: "type", values: ["schema"]} = filter

      assert %{
               id: _,
               priority: 0,
               class: "prod",
               property: "external_id",
               regex: ~r/glue:\/\/.*/
             } = r1

      assert %{
               id: _,
               priority: 10,
               class: "dev",
               property: "metadata.foo.bar",
               values: ["whatever"]
             } = r2
    end
  end

  describe "Classifiers.create_filter/2" do
    test "creates a filter" do
      %{id: classifier_id} = classifier = insert(:classifier)
      params = %{"property" => "bar", "regex" => "baz"}
      assert {:ok, filter} = Classifiers.create_filter(classifier, params)
      assert %{classifier_id: ^classifier_id, property: "bar", regex: ~r/baz/} = filter
    end
  end

  describe "Classifiers.create_rule/2" do
    test "creates a rule" do
      %{id: classifier_id} = classifier = insert(:classifier)
      params = %{"class" => "foo", "property" => "bar", "regex" => "baz"}
      assert {:ok, rule} = Classifiers.create_rule(classifier, params)

      assert %{classifier_id: ^classifier_id, class: "foo", property: "bar", regex: ~r/baz/} =
               rule
    end
  end

  describe "Classifiers.delete_classifier/2" do
    test "deletes a classifier" do
      classifier = insert(:classifier)
      assert {:ok, %{__meta__: meta}} = Classifiers.delete_classifier(classifier)
      assert %{state: :deleted} = meta
    end
  end

  describe "Classifiers.delete_filter/2" do
    test "deletes a filter" do
      filter = insert(:classifier_filter)
      assert {:ok, %{__meta__: meta}} = Classifiers.delete_filter(filter)
      assert %{state: :deleted} = meta
    end
  end

  describe "Classifiers.delete_rule/2" do
    test "deletes a rule" do
      rule = insert(:regex_rule)
      assert {:ok, %{__meta__: meta}} = Classifiers.delete_rule(rule)
      assert %{state: :deleted} = meta
    end
  end
end
