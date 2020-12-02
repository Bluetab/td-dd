defmodule TdDq.Rules.RuleResultTest do
  use TdDq.DataCase

  alias Ecto.Changeset
  alias TdDq.Repo
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

    test "accepts large values in errors and records fields" do
      {errors, records} = {4_715_670_290, 9_223_372_036_854_775_807}

      assert {:ok, %{id: id}} =
               :rule_result
               |> string_params_for(records: records, errors: errors, result: 0)
               |> RuleResult.changeset()
               |> Repo.insert()

      assert %{errors: ^errors, records: ^records} = Repo.get!(RuleResult, id)
    end
  end
end
