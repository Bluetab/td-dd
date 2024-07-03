defmodule TdDq.Executions.GroupTest do
  use TdDd.DataCase

  alias TdDd.Repo
  alias TdDq.Executions.Group

  @unsafe "javascript:alert(document)"

  describe "changeset/2" do
    test "validates required fields" do
      assert %{errors: errors} = Group.changeset(%{})
      assert {_, [validation: :required]} = errors[:created_by_id]
    end

    test "validates required assocs" do
      params = %{"created_by_id" => 0, "executions" => []}
      assert %{errors: errors} = Group.changeset(params)
      assert {_, [validation: :required]} = errors[:executions]
    end

    test "validates unsafe content" do
      %{id: id} = insert(:implementation)

      params = %{
        "created_by_id" => 0,
        "executions" => [%{"implementation_id" => id}],
        "df_content" => %{"doc" => %{"value" => @unsafe, "origin" => "user"}}
      }

      assert %{valid?: false, errors: errors} = Group.changeset(params)
      assert errors[:df_content] == {"invalid content", []}
    end

    test "casts execution params and inserts correctly" do
      %{id: id1} = insert(:implementation)
      %{id: id2} = insert(:implementation)

      params = %{
        "created_by_id" => 0,
        "executions" => [
          %{"implementation_id" => id1},
          %{"implementation_id" => id2}
        ]
      }

      assert {:ok, group} =
               params
               |> Group.changeset()
               |> Repo.insert()

      assert %{id: group_id, executions: [execution1, execution2]} = group
      assert %{group_id: ^group_id, implementation_id: ^id1} = execution1
      assert %{group_id: ^group_id, implementation_id: ^id2} = execution2
    end
  end
end
