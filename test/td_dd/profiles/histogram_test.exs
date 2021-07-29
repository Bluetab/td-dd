defmodule TdDd.Profiles.HistogramTest do
  use TdDd.DataCase

  alias TdDd.Profiles.Histogram

  @distribution [["foo", 123], ["foo", "-123.0"], ["bar", -456]]

  describe "Histogram.cast/1" do
    test "rejects strings which are not valid JSON encodings" do
      assert Histogram.cast("foo") == :error
    end

    test "rejects items with non-numeric values" do
      assert Histogram.cast([["foo", "foo"]]) == :error
    end

    test "rejects items with non-integer values" do
      assert Histogram.cast([["foo", "123.4"]]) == :error
    end

    test "accepts items with integer values expressed as decimals" do
      assert {:ok, [%{"v" => -123}]} = Histogram.cast([["foo", "-123.0"]])
    end

    test "accepts any type of key" do
      assert {:ok, [%{"k" => 123}, %{"k" => ["array"]}, %{"k" => %{"foo" => "bar"}}]} =
               Histogram.cast([[123, 0], [["array"], 1], [%{"foo" => "bar"}, -6]])
    end

    test "converts pairs to items with keys and values" do
      assert {:ok, dist} = Histogram.cast(@distribution)

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
               |> Histogram.cast()

      assert dist == [
               %{"k" => "foo", "v" => 123},
               %{"k" => "foo", "v" => -123},
               %{"k" => "bar", "v" => -456}
             ]
    end
  end
end
