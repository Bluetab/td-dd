defmodule TdDq.Executions.ExecutionTest do
  use TdDq.DataCase

  alias TdDq.Executions.Execution
  alias TdDq.Repo

  describe "changeset/2" do
    test "validates required fields" do
      assert %{errors: errors} = Execution.changeset(%{})

      assert {_, [validation: :required]} = errors[:implementation_id]
    end

    test "captures foreign key constraint on group_id" do
      %{id: implementation_id} = insert(:implementation)

      assert {:error, %{errors: errors}} =
               %{group_id: -1, implementation_id: implementation_id}
               |> Execution.changeset()
               |> Repo.insert()

      assert {_, [constraint: :foreign, constraint_name: "executions_group_id_fkey"]} =
               errors[:group_id]
    end

    test "captures foreign key constraint on implementation_id" do
      %{id: group_id} = insert(:execution_group)

      assert {:error, %{errors: errors}} =
               %{group_id: group_id, implementation_id: -1}
               |> Execution.changeset()
               |> Repo.insert()

      assert {_, [constraint: :foreign, constraint_name: "executions_implementation_id_fkey"]} =
               errors[:implementation_id]
    end
  end
end
