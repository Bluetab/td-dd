defmodule TdDd.Profiles.CountTest do
  use TdDd.DataCase

  alias TdDd.Profiles.Count

  describe "Count.cast/1" do
    test "rejects negative integers" do
      assert Count.cast(-1) == :error
    end

    test "accepts non-negative integers" do
      assert {:ok, 0} = Count.cast(0)
      assert {:ok, 42} = Count.cast(42)
    end

    test "accepts non-negative integers expressed as decimals" do
      assert {:ok, 0} = Count.cast("0.00000")
      assert {:ok, 42} = Count.cast("42.0")
    end
  end
end
