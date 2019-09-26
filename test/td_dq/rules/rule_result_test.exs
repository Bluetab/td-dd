defmodule TdDq.Rules.RuleResultTest do
  use ExUnit.Case

  alias Ecto.Changeset
  alias TdDq.Rules.RuleResult

  @date DateTime.from_naive!(~N[2015-01-23 00:00:00], "Etc/UTC")
  @datetime DateTime.from_naive!(~N[2015-01-23 23:50:07], "Etc/UTC")

  describe "TdDq.Rules.RuleResult" do
    test "changeset/2 accepts date format YYYY-MM-DD" do
      attrs = %{"date" => "2015-01-23"}

      assert {:ok, date} =
               %RuleResult{}
               |> RuleResult.changeset(attrs)
               |> Changeset.fetch_change(:date)

      assert date == @date
    end

    test "changeset/2 accepts date format YYYY-MM-DD-HH-MM-SS" do
      attrs = %{"date" => "2015-01-23-23-50-07"}

      assert {:ok, date} =
               %RuleResult{}
               |> RuleResult.changeset(attrs)
               |> Changeset.fetch_change(:date)

      assert date == @datetime
    end

    test "changeset/2 accepts ISO8601 date format with timezone" do
      attrs = %{"date" => "2015-01-24T01:50:07+02:00"}

      assert {:ok, date} =
               %RuleResult{}
               |> RuleResult.changeset(attrs)
               |> Changeset.fetch_change(:date)

      assert date == @datetime
    end

    test "changeset/2 accepts ISO8601 date format without timezone" do
      attrs = %{"date" => "2015-01-23 23:50:07"}

      assert {:ok, date} =
               %RuleResult{}
               |> RuleResult.changeset(attrs)
               |> Changeset.fetch_change(:date)

      assert date == @datetime
    end
  end
end
