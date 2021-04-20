defmodule TdDq.DateParserTest do
  use ExUnit.Case

  alias TdDq.DateParser

  doctest TdDq.DateParser

  @datetime DateTime.from_naive!(~N[2015-01-23 23:50:07], "Etc/UTC")
  @date DateTime.from_naive!(~N[2015-01-23 00:00:00], "Etc/UTC")

  describe "TdDq.DateParser" do
    test "parse/1 parses a valid ISO8601 date string" do
      assert {:ok, datetime, 7200} = DateParser.parse("2015-01-24T01:50:07+02:00")
      assert DateTime.compare(datetime, @datetime) == :eq
    end

    test "parse/1 parses a date time as UTC if no timezone is specified" do
      assert {:ok, datetime, 0} = DateParser.parse("2015-01-23 23:50:07")
      assert DateTime.compare(datetime, @datetime) == :eq
    end

    test "parse/1 parses a date in format YYYY-MM-DD as a UTC datetime" do
      assert {:ok, datetime, 0} = DateParser.parse("2015-01-23")
      assert DateTime.compare(datetime, @date) == :eq
    end

    test "parse/1 parses a date in legacy format as a UTC datetime" do
      assert {:ok, datetime, 0} = DateParser.parse("2015-01-23-23-50-07")
      assert DateTime.compare(datetime, @datetime) == :eq
    end

    test "parse/1 returns an invalid_date error for invalid dates" do
      assert {:error, :invalid_date} = DateParser.parse("2015-02-29T23:50:07Z")
      assert {:error, :invalid_date} = DateParser.parse("2015-02-29-23-50-07")
      assert {:error, :invalid_date} = DateParser.parse("2015-02-29")
    end

    test "parse/1 returns an invalid_time error for invalid times" do
      assert {:error, :invalid_time} = DateParser.parse("2015-01-23T24:00:00Z")
      assert {:error, :invalid_time} = DateParser.parse("2015-01-23-20-62-01")
    end

    test "parse/1 returns an invalid_format error for invalid formats" do
      assert {:error, :invalid_format} = DateParser.parse("2015-01-23T23:50:07+24:00")
      assert {:error, :invalid_format} = DateParser.parse("2015-01-23T23:50:07-00:00")
      assert {:error, :invalid_format} = DateParser.parse("2015-01-23T23:50:07+0:00")
      assert {:error, :invalid_format} = DateParser.parse("2015-01-23-23-50-07-12")
      assert {:error, :invalid_format} = DateParser.parse("foo")
    end
  end
end
