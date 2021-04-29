defmodule TdDd.Executions.ProfileExecutionTest do
  use TdDd.DataCase

  alias TdDd.Executions.ProfileExecution
  alias TdDd.Repo

  describe "changeset/2" do
    test "validates required fields" do
      assert %{errors: errors} = ProfileExecution.changeset(%{})

      assert {_, [validation: :required]} = errors[:data_structure_id]
    end

    test "returns changeset when fields are valid" do
      %{id: id} = insert(:data_structure)
      %{id: group_id} = insert(:profile_execution_group)

      assert {:ok, %{data_structure_id: ^id, profile_group_id: ^group_id}} =
               %{profile_group_id: group_id, data_structure_id: id}
               |> ProfileExecution.changeset()
               |> Repo.insert()
    end

    test "captures foreign key constraint on profile_group_id" do
      %{id: id} = insert(:data_structure)

      assert {:error, %{errors: errors}} =
               %{profile_group_id: 1, data_structure_id: id}
               |> ProfileExecution.changeset()
               |> Repo.insert()

      assert {_,
              [constraint: :foreign, constraint_name: "profile_executions_profile_group_id_fkey"]} =
               errors[:profile_group_id]
    end

    test "captures foreign key constraint on implementation_id" do
      %{id: group_id} = insert(:profile_execution_group)

      assert {:error, %{errors: errors}} =
               %{profile_group_id: group_id, data_structure_id: 1}
               |> ProfileExecution.changeset()
               |> Repo.insert()

      assert {_,
              [constraint: :foreign, constraint_name: "profile_executions_data_structure_id_fkey"]} =
               errors[:data_structure_id]
    end

    test "manages profile events" do
      %{id: group_id} = insert(:profile_execution_group)
      %{id: id} = insert(:data_structure)

      assert {:ok, %{id: id}} =
               %{
                 "data_structure_id" => id,
                 "profile_group_id" => group_id,
                 "profile_events" => [%{"type" => "PENDING"}]
               }
               |> ProfileExecution.changeset()
               |> Repo.insert()

      assert %{profile_events: [%{type: "PENDING"}]} =
               ProfileExecution
               |> Repo.get(id)
               |> Repo.preload(:profile_events)
    end
  end
end
