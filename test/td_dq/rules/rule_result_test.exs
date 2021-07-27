defmodule TdDq.Rules.RuleResultTest do
  use TdDd.DataCase

  alias Ecto.Changeset
  alias TdDd.Repo
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
               |> string_params_for(
                 records: records,
                 result_type: "percentage",
                 errors: errors,
                 result: 0
               )
               |> RuleResult.changeset()
               |> Repo.insert()

      assert %{errors: ^errors, records: ^records} = Repo.get!(RuleResult, id)
    end

    test "puts calculated result if not present in changeset" do
      {errors, records} = {123_456, 456_123}

      assert "72.93" =
               %{
                 "records" => records,
                 "errors" => errors,
                 "implementation_key" => "foo",
                 "date" => "2020-01-01"
               }
               |> RuleResult.changeset()
               |> Changeset.get_change(:result)
               |> Decimal.to_string()
    end

    test "accepts string values for errors and records" do
      params = %{"errors" => "123456", "records" => "654321"}
      changeset = RuleResult.changeset(params)
      assert Changeset.fetch_change!(changeset, :errors) == 123_456
      assert Changeset.fetch_change!(changeset, :records) == 654_321
    end

    test "validates errors and records are non-negative if present" do
      params = %{"errors" => -1, "records" => -2}
      assert %{errors: errors} = RuleResult.changeset(params)

      assert {_, [validation: :number, kind: :greater_than_or_equal_to, number: 0]} =
               errors[:errors]

      assert {_, [validation: :number, kind: :greater_than_or_equal_to, number: 0]} =
               errors[:records]
    end

    test "rounds result to two decimal places" do
      params = %{"result" => 123.456_789}

      assert "123.45" ==
               params
               |> RuleResult.changeset()
               |> Changeset.get_change(:result)
               |> Decimal.to_string()
    end
  end
end
