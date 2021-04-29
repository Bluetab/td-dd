defmodule EctoRegexTest do
  use ExUnit.Case

  describe "EctoRegex.cast/1" do
    test "casts a valid string to a regex" do
      assert EctoRegex.cast("foo") == {:ok, ~r/foo/}
    end

    test "returns error for invalid regex" do
      assert EctoRegex.cast("*foo") == :error
    end
  end

  describe "EctoRegex.dump/1" do
    test "returns the source of the regex" do
      assert EctoRegex.dump(~r/foo/) == {:ok, "foo"}
    end

    test "returns error for invalid regex" do
      assert EctoRegex.dump(123) == :error
    end
  end
end
