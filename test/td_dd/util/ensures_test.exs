defmodule TdDd.Util.EnsuresTest do
  use ExUnit.Case

  alias TdDd.Util.Ensures

  describe "number/1" do
    test "returns number when input is a number" do
      assert Ensures.number(42) == 42
      assert Ensures.number(0) == 0
      assert Ensures.number(-10) == -10
      assert Ensures.number(3.14) == 3.14
    end

    test "converts string to integer when input is a binary" do
      assert Ensures.number("42") == 42
      assert Ensures.number("0") == 0
      assert Ensures.number("-10") == -10
    end
  end

  describe "list/1" do
    test "returns list when input is already a list" do
      assert Ensures.list([]) == []
      assert Ensures.list([1, 2, 3]) == [1, 2, 3]
      assert Ensures.list(["a", "b"]) == ["a", "b"]
    end

    test "wraps value in list when input is not a list" do
      assert Ensures.list(42) == [42]
      assert Ensures.list("hello") == ["hello"]
      assert Ensures.list(%{foo: "bar"}) == [%{foo: "bar"}]
      assert Ensures.list(nil) == [nil]
    end
  end

  describe "tuple/1" do
    test "returns tuple when input is already a tuple" do
      assert Ensures.tuple({1, 2}) == {1, 2}
      assert Ensures.tuple({}) == {}
      assert Ensures.tuple({:ok, "value"}) == {:ok, "value"}
    end

    test "wraps value in tuple with 0 when input is not a tuple" do
      assert Ensures.tuple(42) == {42, 0}
      assert Ensures.tuple("hello") == {"hello", 0}
      assert Ensures.tuple([1, 2]) == {[1, 2], 0}
      assert Ensures.tuple(nil) == {nil, 0}
    end
  end

  describe "map/1" do
    test "returns map when input is already a map" do
      assert Ensures.map(%{}) == %{}
      assert Ensures.map(%{foo: "bar"}) == %{foo: "bar"}
      assert Ensures.map(%{"key" => "value"}) == %{"key" => "value"}
    end

    test "wraps value in map when input is not a map" do
      assert Ensures.map(42) == %{value: 42}
      assert Ensures.map("hello") == %{value: "hello"}
      assert Ensures.map([1, 2]) == %{value: [1, 2]}
      assert Ensures.map(nil) == %{value: nil}
    end
  end

  describe "string/1" do
    test "returns string when input is already a binary" do
      assert Ensures.string("hello") == "hello"
      assert Ensures.string("") == ""
      assert Ensures.string("123") == "123"
    end

    test "converts value to string when input is not a binary" do
      assert Ensures.string(42) == "42"
      assert Ensures.string(3.14) == "3.14"
      assert Ensures.string(:atom) == "atom"
      assert Ensures.string(true) == "true"
      assert Ensures.string(false) == "false"
    end
  end
end
