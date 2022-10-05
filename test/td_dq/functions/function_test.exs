defmodule TdDq.Functions.FunctionTest do
  use TdDd.DataCase

  alias TdDd.Repo
  alias TdDq.Functions.Function

  describe "Function.changeset/2" do
    test "validates args" do
      params = string_params_for(:function, args: nil)
      assert %{valid?: false} = Function.changeset(params)

      params = string_params_for(:function, args: [])
      assert %{valid?: false} = Function.changeset(params)

      params = string_params_for(:function, args: [%{}])
      assert %{valid?: false} = Function.changeset(params)

      params = string_params_for(:function, args: [build(:argument)])
      assert %{valid?: true} = Function.changeset(params)
    end

    test "captures unique constraint on name and args" do
      params = string_params_for(:function)

      assert {:ok, _} =
               params
               |> Function.changeset()
               |> Repo.insert()

      assert {:error, %{errors: errors}} =
               params
               |> Function.changeset()
               |> Repo.insert()

      assert {_, [constraint: :unique, constraint_name: "functions_name_args_index"]} =
               errors[:name]
    end

    test "captures unique constraint on name, group and args" do
      params = string_params_for(:function, group: "g1")

      assert {:ok, _} =
               params
               |> Function.changeset()
               |> Repo.insert()

      assert {:error, %{errors: errors}} =
               params
               |> Function.changeset()
               |> Repo.insert()

      assert {_, [constraint: :unique, constraint_name: "functions_name_args_group_index"]} =
               errors[:name]
    end

    test "captures unique constraint on name, scope and args" do
      params = string_params_for(:function, scope: "s1")

      assert {:ok, _} =
               params
               |> Function.changeset()
               |> Repo.insert()

      assert {:error, %{errors: errors}} =
               params
               |> Function.changeset()
               |> Repo.insert()

      assert {_, [constraint: :unique, constraint_name: "functions_name_args_scope_index"]} =
               errors[:name]
    end

    test "captures unique constraint on name, group, scope and args" do
      params = string_params_for(:function, group: "g1", scope: "s1")

      assert {:ok, _} =
               params
               |> Function.changeset()
               |> Repo.insert()

      assert {:error, %{errors: errors}} =
               params
               |> Function.changeset()
               |> Repo.insert()

      assert {_, [constraint: :unique, constraint_name: "functions_name_args_group_scope_index"]} =
               errors[:name]
    end
  end
end
