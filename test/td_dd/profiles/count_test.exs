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

    test "rejects negative integers expressed as decimals" do
      assert Count.cast("-1.0") == :error
    end

    test "rejects invalid binary values" do
      assert Count.cast("abc") == :error
      assert Count.cast("12.34.56") == :error
    end

    test "rejects non-numeric values" do
      assert Count.cast(%{}) == :error
      assert Count.cast([]) == :error
      assert Count.cast(nil) == :error
    end
  end

  describe "Count.load/1" do
    test "loads non-negative integers" do
      assert {:ok, 0} = Count.load(0)
      assert {:ok, 42} = Count.load(42)
    end

    test "rejects negative integers" do
      assert Count.load(-1) == :error
    end

    test "rejects non-integer values" do
      assert Count.load("42") == :error
      assert Count.load(nil) == :error
    end
  end

  describe "Count.dump/1" do
    test "dumps non-negative integers" do
      assert {:ok, 0} = Count.dump(0)
      assert {:ok, 42} = Count.dump(42)
    end

    test "rejects negative integers" do
      assert Count.dump(-1) == :error
    end

    test "rejects non-integer values" do
      assert Count.dump("42") == :error
      assert Count.dump(nil) == :error
    end
  end

  describe "Count.type/0" do
    test "returns integer type" do
      assert Count.type() == :integer
    end
  end
end
