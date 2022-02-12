defmodule TdDd.HelpersTest do
  use ExUnit.Case

  alias TdDd.Helpers

  test "validates required fields" do
    assert Helpers.shift_zone("2011-12-13T00:00:00Z", "Europe/Madrid") == "2011-12-13T01:00:00+01:00"
    assert Helpers.shift_zone("2009-08-07T00:00:00Z", "Europe/Madrid") == "2009-08-07T02:00:00+02:00"
  end
end
