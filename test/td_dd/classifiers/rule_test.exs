defmodule TdDd.Classifiers.RuleTest do
  use TdDd.DataCase

  alias TdDd.Classifiers.Rule
  alias TdDd.Repo

  describe "Rule.changeset/2" do
    test "validates required fields" do
      assert %{valid?: false, errors: errors} = Rule.changeset(%{})
      assert {_, [validation: :required]} = errors[:class]
      assert {_, [validation: :required]} = errors[:property]
      refute Keyword.has_key?(errors, :priority)
    end

    test "casts and validates parameters" do
      %{id: classifier_id} = insert(:classifier)
      params = %{classifier_id: classifier_id, property: "foo", regex: "foo", class: "foo"}
      assert %{valid?: true, changes: changes} = Rule.changeset(params)
      assert %{regex: ~r/foo/, property: "foo", classifier_id: ^classifier_id} = changes
    end

    test "validates values is not empty" do
      %{id: classifier_id} = insert(:classifier)
      params = %{classifier_id: classifier_id, class: "bar", property: "bar", values: []}
      assert %{valid?: false, errors: errors} = Rule.changeset(params)
      assert {_, [count: 1, validation: :length, kind: :min, type: :list]} = errors[:values]
    end

    test "removes duplicate values" do
      %{id: classifier_id} = insert(:classifier)

      params = %{
        classifier_id: classifier_id,
        class: "baz",
        property: "baz",
        values: ["1", "2", "1"]
      }

      assert %{valid?: true, changes: changes} = Rule.changeset(params)
      assert %{values: ["1", "2"], property: "baz", classifier_id: ^classifier_id} = changes
    end

    test "captures foreign key constraint on classifier_id" do
      assert {:error, %{errors: errors} = changeset} =
               %{classifier_id: 1, property: "foo", regex: "foo", class: "class"}
               |> Rule.changeset()
               |> Repo.insert()

      refute changeset.valid?

      assert {_, [constraint: :foreign, constraint_name: "classifier_rules_classifier_id_fkey"]} =
               errors[:classifier_id]
    end

    test "captures check constraint on values and regex" do
      %{id: classifier_id} = insert(:classifier)

      assert {:error, %{errors: errors} = changeset} =
               %{
                 class: "class",
                 classifier_id: classifier_id,
                 property: "foo",
                 regex: "foo",
                 values: ["bar"]
               }
               |> Rule.changeset()
               |> Repo.insert()

      refute changeset.valid?
      assert {_, [constraint: :check, constraint_name: "values_xor_regex"]} = errors[:values]
    end
  end
end
