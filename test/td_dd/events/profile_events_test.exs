defmodule TdDd.Events.ProfileEventsTest do
  @moduledoc false
  use TdDd.DataCase

  alias TdDd.Events.ProfileEvents

  describe "create_event/1" do
    test "validates required fields" do
      assert {:error, %{errors: errors}} = ProfileEvents.create_event(%{})
      assert {_, [validation: :required]} = errors[:profile_execution_id]
    end

    test "validates message length" do
      message = String.duplicate("foo", 334)
      %{id: id} = insert(:profile_execution)

      assert {:error, %{errors: errors}} =
               ProfileEvents.create_event(%{profile_execution_id: id, message: message})

      assert {_, [count: 1000, validation: :length, kind: :max, type: :string]} = errors[:message]
    end

    test "creates event" do
      message = "foo"
      type = "bar"
      %{id: id} = insert(:profile_execution)

      assert {:ok, %{profile_execution_id: ^id, message: ^message, type: ^type}} =
               ProfileEvents.create_event(%{
                 profile_execution_id: id,
                 message: message,
                 type: type
               })
    end
  end

  describe "complete/1" do
    test "sets to succeeded a group executions" do
      %{id: id1} = insert(:profile_execution)
      %{id: id2} = insert(:profile_execution)

      assert {2, [%{profile_execution_id: ^id1}, %{profile_execution_id: ^id2}]} =
               ProfileEvents.complete([id1, id2])
    end
  end
end
