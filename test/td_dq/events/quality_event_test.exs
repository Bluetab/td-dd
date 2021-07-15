defmodule TdDq.Events.QualityEventTest do
  @moduledoc false
  use TdDd.DataCase

  alias TdDd.Repo
  alias TdDq.Events.QualityEvent

  describe "create_changeset/1" do
    test "validate required fields" do
      assert %{errors: errors} = QualityEvent.create_changeset(%{})

      assert {_, [validation: :required]} = errors[:execution_id]
    end

    test "return changeset when fields are valid" do
      message = "foo"
      type = "bar"

      %{id: id} =
        insert(:execution,
          group: build(:execution_group),
          implementation: build(:implementation, rule: build(:rule))
        )

      assert {:ok,
              %{
                execution_id: ^id,
                message: ^message,
                type: ^type
              }} =
               %{execution_id: id, message: message, type: type}
               |> QualityEvent.create_changeset()
               |> Repo.insert()
    end

    test "validates message size" do
      message = String.duplicate("foo", 334)
      type = "bar"

      %{id: id} =
        insert(:execution,
          group: build(:execution_group),
          implementation: build(:implementation, rule: build(:rule))
        )

      assert %{errors: errors} =
               QualityEvent.changeset(%{
                 execution_id: id,
                 message: message,
                 type: type
               })

      assert {_, [count: 1000, validation: :length, kind: :max, type: :string]} = errors[:message]
    end
  end
end
