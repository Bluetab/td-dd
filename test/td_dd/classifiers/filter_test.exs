defmodule TdDd.Classifiers.FilterTest do
  use TdDd.DataCase

  alias TdDd.Classifiers.Filter
  alias TdDd.Repo

  describe "Filter.changeset/2" do
    test "validates required fields" do
      assert %{valid?: false, errors: errors} = Filter.changeset(%{})
      assert {_, [validation: :required]} = errors[:path]
    end

    test "casts and validates parameters" do
      %{id: classifier_id} = insert(:classifier)
      params = %{classifier_id: classifier_id, path: ["type"], regex: "foo"}
      assert %{valid?: true, changes: changes} = Filter.changeset(params)
      assert %{regex: ~r/foo/, path: ["type"], classifier_id: ^classifier_id} = changes
    end

    test "validates values is not empty" do
      %{id: classifier_id} = insert(:classifier)
      params = %{classifier_id: classifier_id, path: ["type"], values: []}
      assert %{valid?: false, errors: errors} = Filter.changeset(params)
      assert {_, [count: 1, validation: :length, kind: :min, type: :list]} = errors[:values]
    end

    test "removes duplicate values" do
      %{id: classifier_id} = insert(:classifier)
      params = %{classifier_id: classifier_id, path: ["type"], values: ["bar", "baz", "bar"]}
      assert %{valid?: true, changes: changes} = Filter.changeset(params)
      assert %{values: ["bar", "baz"], path: ["type"], classifier_id: ^classifier_id} = changes
    end

    test "captures foreign key constraint on classifier_id" do
      assert {:error, %{errors: errors} = changeset} =
               %{classifier_id: 1, path: ["type"], regex: "foo"}
               |> Filter.changeset()
               |> Repo.insert()

      refute changeset.valid?

      assert {_, [constraint: :foreign, constraint_name: "classifier_filters_classifier_id_fkey"]} =
               errors[:classifier_id]
    end

    test "captures check constraint on values and regex" do
      %{id: classifier_id} = insert(:classifier)

      assert {:error, %{errors: errors} = changeset} =
               %{classifier_id: classifier_id, path: ["type"], regex: "foo", values: ["bar"]}
               |> Filter.changeset()
               |> Repo.insert()

      refute changeset.valid?
      assert {_, [constraint: :check, constraint_name: "values_xor_regex"]} = errors[:values]
    end
  end
end
