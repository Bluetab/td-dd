defmodule TdDd.Executions.ProfileGroupTest do
  use TdDd.DataCase

  alias TdDd.Executions.ProfileGroup
  alias TdDd.Repo

  describe "changeset/2" do
    test "validates required fields" do
      assert %{errors: errors} = ProfileGroup.changeset(%{})
      assert {_, [validation: :required]} = errors[:created_by_id]
    end

    test "casts execution params and inserts correctly" do
      %{id: id1} = insert(:data_structure)
      %{id: id2} = insert(:data_structure)

      params = %{
        "created_by_id" => 0,
        "executions" => [
          %{"data_structure_id" => id1},
          %{"data_structure_id" => id2}
        ]
      }

      assert {:ok, group} =
               params
               |> ProfileGroup.changeset()
               |> Repo.insert()

      assert %{id: group_id, executions: [execution1, execution2]} = group

      assert %{
               profile_group_id: ^group_id,
               data_structure_id: ^id1
             } = execution1

      assert %{
               profile_group_id: ^group_id,
               data_structure_id: ^id2
             } = execution2
    end
  end
end
