defmodule Jason.EncoderTest do
  use ExUnit.Case

  describe "Jason.Encoder implementation" do
    test "serializes a tuple as a list" do
      assert Jason.encode!({"foo", 2, :bar}) == ~s(["foo",2,"bar"])
    end
  end
end
