defmodule TdDq.Rules.RuleResultTest do
  use ExUnit.Case

  alias Ecto.Changeset
  alias TdDq.Rules.RuleResult

  @date DateTime.from_naive!(~N[2015-01-23 00:00:00], "Etc/UTC")
  @datetime DateTime.from_naive!(~N[2015-01-23 23:50:07], "Etc/UTC")

  describe "changeset/2" do
    test "accepts date format YYYY-MM-DD" do
      params = %{"date" => "2015-01-23"}

      assert {:ok, date} =
               params
               |> RuleResult.changeset()
               |> Changeset.fetch_change(:date)

      assert date == @date
    end

    test "accepts date format YYYY-MM-DD-HH-MM-SS" do
      params = %{"date" => "2015-01-23-23-50-07"}

      assert {:ok, date} =
               params
               |> RuleResult.changeset()
               |> Changeset.fetch_change(:date)

      assert date == @datetime
    end

    test "accepts ISO8601 date format with timezone" do
      params = %{"date" => "2015-01-24T01:50:07+02:00"}

      assert {:ok, date} =
               params
               |> RuleResult.changeset()
               |> Changeset.fetch_change(:date)

      assert date == @datetime
    end

    test "accepts ISO8601 date format without timezone" do
      params = %{"date" => "2015-01-23 23:50:07"}

      assert {:ok, date} =
               params
               |> RuleResult.changeset()
               |> Changeset.fetch_change(:date)

      assert date == @datetime
    end

    test "accepts row_number" do
      params = %{"row_number" => 123}

      assert {:ok, row_number} =
               params
               |> RuleResult.changeset()
               |> Changeset.fetch_change(:row_number)

      assert row_number == 123
    end
  end
end
