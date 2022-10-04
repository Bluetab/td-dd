defmodule TdDq.Functions.FunctionTest do
  use TdDd.DataCase

  alias TdDd.Repo
  alias TdDq.Functions.Function

  describe "changeset/2" do
    test "validates args" do
      params = params_for(:function, args: [%{"foo" => "bar"}])

      assert %{valid?: true} = Function.changeset(params)
    end

    test "captures unique constraint on name and args" do
      params = insert(:function) |> Map.take([:name, :args])

      assert {:error, %{errors: errors}} =
               params
               |> Function.changeset()
               |> Repo.insert()

      assert {_, [constraint: :unique, constraint_name: "functions_name_args_index"]} =
               errors[:name]
    end

    test "captures unique constraint on name, group and args" do
      params = insert(:function, group: "g1") |> Map.take([:name, :args, :group])

      assert {:error, %{errors: errors}} =
               params
               |> Function.changeset()
               |> Repo.insert()

      assert {_, [constraint: :unique, constraint_name: "functions_name_args_group_index"]} =
               errors[:name]
    end

    test "captures unique constraint on name, scope and args" do
      params = insert(:function, scope: "s1") |> Map.take([:name, :args, :scope])

      assert {:error, %{errors: errors}} =
               params
               |> Function.changeset()
               |> Repo.insert()

      assert {_, [constraint: :unique, constraint_name: "functions_name_args_scope_index"]} =
               errors[:name]
    end

    test "captures unique constraint on name, group, scope and args" do
      params =
        insert(:function, group: "g1", scope: "s1") |> Map.take([:name, :args, :group, :scope])

      assert {:error, %{errors: errors}} =
               params
               |> Function.changeset()
               |> Repo.insert()

      assert {_, [constraint: :unique, constraint_name: "functions_name_args_group_scope_index"]} =
               errors[:name]
    end
  end
end
