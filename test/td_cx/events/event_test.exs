defmodule TdCx.Events.EventTest do
  use ExUnit.Case

  alias TdCx.Events.Event

  test "validates length of message" do
    message = 1..1001 |> Enum.map(fn _ -> "." end) |> Enum.join()

    assert %{errors: errors} =
             %{"message" => message}
             |> Event.changeset()

    assert {_, [count: 1000, validation: :length, kind: :max, type: :string]} = errors[:message]
  end
end
