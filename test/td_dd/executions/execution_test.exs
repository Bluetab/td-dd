defmodule TdDd.Executions.ExecutionTest do
  use TdDd.DataCase

  alias TdDd.Executions.Execution
  alias TdDd.Repo

  describe "changeset/2" do
    test "validates required fields" do
      assert %{errors: errors} = Execution.changeset(%{})

      assert {_, [validation: :required]} = errors[:data_structure_id]
    end

    test "captures foreign key constraint on group_id" do
      %{id: id} = insert(:data_structure)

      assert {:error, %{errors: errors}} =
               %{group_id: 1, data_structure_id: id}
               |> Execution.changeset()
               |> Repo.insert()

      assert {_, [constraint: :foreign, constraint_name: "executions_group_id_fkey"]} =
               errors[:group_id]
    end

    test "captures foreign key constraint on implementation_id" do
      %{id: group_id} = insert(:execution_group)

      assert {:error, %{errors: errors}} =
               %{group_id: group_id, data_structure_id: 1}
               |> Execution.changeset()
               |> Repo.insert()

      assert {_, [constraint: :foreign, constraint_name: "executions_data_structure_id_fkey"]} =
               errors[:data_structure_id]
    end
  end
end
