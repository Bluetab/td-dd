defmodule TdDq.Events.QualityEventsTest do
  @moduledoc false

  use TdDd.DataCase

  alias TdDq.Events.QualityEvents

  describe "create_event/1" do
    test "validates required fields" do
      assert {:error, %{errors: errors}} = QualityEvents.create_event(%{})
      assert {_, [validation: :required]} = errors[:execution_id]
    end

    test "creates event" do
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
               QualityEvents.create_event(%{
                 execution_id: id,
                 message: message,
                 type: type
               })
    end
  end
end
