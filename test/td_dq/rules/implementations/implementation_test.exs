defmodule TdDq.Rules.Implementations.ImplementationTest do
  use TdDq.DataCase

  alias TdDd.Repo
  alias TdDq.Rules.Implementations.Implementation

  describe "changeset/2" do
    test "validates existence of rule on insert" do
      params =
        :implementation
        |> string_params_for()
        |> Map.delete("rule")
        |> Map.put("rule_id", 123)

      assert %{valid?: true} = changeset = Implementation.changeset(params)
      assert {:error, changeset} = Repo.insert(changeset)
      assert %{errors: errors} = changeset
      assert {_msg, [constraint: :foreign, constraint_name: _constraint_name]} = errors[:rule_id]
    end

    test "puts next available implementation_key if none specified and changeset valid" do
      insert(:implementation, implementation_key: "ri0123")
      %{id: rule_id} = insert(:rule)

      params =
        :implementation
        |> string_params_for(rule_id: rule_id)
        |> Map.delete("implementation_key")

      assert %{changes: changes, valid?: true} = Implementation.changeset(params)
      assert %{implementation_key: "ri0124"} = changes
    end

    test "does not automatically put implementation_key if one is specified" do
      params = %{implementation_key: "foo"}

      assert %{changes: changes} = Implementation.changeset(params)
      assert %{implementation_key: "foo"} = changes
    end

    test "does not automatically put implementation_key if changeset is invalid" do
      params = %{}

      assert %{changes: changes, valid?: false} = Implementation.changeset(params)
      refute Map.has_key?(changes, :implementation_key)
    end
  end
end
