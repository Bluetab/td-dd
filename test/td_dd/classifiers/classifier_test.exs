defmodule TdDd.Classifiers.ClassifierTest do
  use TdDd.DataCase

  alias TdDd.Classifiers.Classifier
  alias TdDd.Repo

  describe "Classifier.changeset/2" do
    test "validates required fields" do
      assert %{errors: errors} = Classifier.changeset(%{})

      assert {_, [validation: :required]} = errors[:system_id]
      assert {_, [validation: :required]} = errors[:name]
      assert {_, [validation: :required]} = errors[:rules]
    end

    test "casts the filters association" do
      %{id: system_id} = insert(:system)

      assert {:ok, %Classifier{} = classifier} =
               %{
                 name: "foo",
                 system_id: system_id,
                 rules: [%{path: ["name"], regex: "foo", class: "class"}],
                 filters: [%{path: ["type"], regex: "bar"}]
               }
               |> Classifier.changeset()
               |> Repo.insert()

      assert %{filters: [filter]} = classifier
      assert %{path: ["type"], regex: "bar"} = filter
    end

    test "casts the rules association" do
      %{id: system_id} = insert(:system)

      assert {:ok, %Classifier{} = classifier} =
               %{
                 name: "foo",
                 system_id: system_id,
                 rules: [%{path: ["type"], regex: "foo", class: "class"}]
               }
               |> Classifier.changeset()
               |> Repo.insert()

      assert %{rules: [rule]} = classifier
      assert %{class: "class", path: ["type"], regex: "foo"} = rule
    end

    test "captures unique constraint on name and system_id" do
      %{name: name, system_id: system_id} = insert(:classifier)

      assert {:error, %{errors: errors}} =
               %{
                 name: name,
                 system_id: system_id,
                 rules: [%{path: ["type"], regex: "foo", class: "foo"}]
               }
               |> Classifier.changeset()
               |> Repo.insert()

      assert {_, [constraint: :unique, constraint_name: "classifiers_system_id_name_index"]} =
               errors[:system_id]
    end
  end
end
