defmodule TdDd.Profiles.DistributionTest do
  use TdDd.DataCase

  alias TdDd.Profiles.Distribution

  @distribution [["foo", 123], ["foo", "-123.0"], ["bar", -456]]

  describe "Distribution.cast/1" do
    test "rejects strings which are not valid JSON encodings" do
      assert Distribution.cast("foo") == :error
    end

    test "rejects items with non-numeric values" do
      assert Distribution.cast([["foo", "foo"]]) == :error
    end

    test "rejects items with non-integer values" do
      assert Distribution.cast([["foo", "123.4"]]) == :error
    end

    test "accepts items with integer values expressed as decimals" do
      assert {:ok, [%{"v" => -123}]} = Distribution.cast([["foo", "-123.0"]])
    end

    test "accepts any type of key" do
      assert {:ok, [%{"k" => 123}, %{"k" => ["array"]}, %{"k" => %{"foo" => "bar"}}]} =
               Distribution.cast([[123, 0], [["array"], 1], [%{"foo" => "bar"}, -6]])
    end

    test "converts pairs to items with keys and values" do
      assert {:ok, dist} = Distribution.cast(@distribution)

      assert dist == [
               %{"k" => "foo", "v" => 123},
               %{"k" => "foo", "v" => -123},
               %{"k" => "bar", "v" => -456}
             ]
    end

    test "converts a JSON encoded list to a list with key/value items" do
      assert {:ok, dist} =
               @distribution
               |> Jason.encode!()
               |> Distribution.cast()

      assert dist == [
               %{"k" => "foo", "v" => 123},
               %{"k" => "foo", "v" => -123},
               %{"k" => "bar", "v" => -456}
             ]
    end
  end
end
