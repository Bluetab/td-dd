defmodule TdDq.Rules.RuleResultTest do
  use TdDd.DataCase

  alias Decimal
  alias Ecto.Changeset
  alias TdDd.Repo
  alias TdDq.Rules.RuleResult

  @date DateTime.from_naive!(~N[2015-01-23 00:00:00], "Etc/UTC")
  @datetime DateTime.from_naive!(~N[2015-01-23 23:50:07], "Etc/UTC")

  describe "changeset/2" do
    test "accepts date format YYYY-MM-DD" do
      impl = insert(:implementation)
      params = %{"date" => "2015-01-23"}

      assert {:ok, date} =
               impl
               |> RuleResult.changeset(params)
               |> Changeset.fetch_change(:date)

      assert date == @date
    end

    test "accepts date format YYYY-MM-DD-HH-MM-SS" do
      impl = insert(:implementation)
      params = %{"date" => "2015-01-23-23-50-07"}

      assert {:ok, date} =
               impl
               |> RuleResult.changeset(params)
               |> Changeset.fetch_change(:date)

      assert date == @datetime
    end

    test "accepts ISO8601 date format with timezone" do
      impl = insert(:implementation)
      params = %{"date" => "2015-01-24T01:50:07+02:00"}

      assert {:ok, date} =
               impl
               |> RuleResult.changeset(params)
               |> Changeset.fetch_change(:date)

      assert date == @datetime
    end

    test "accepts ISO8601 date format without timezone" do
      impl = insert(:implementation)
      params = %{"date" => "2015-01-23 23:50:07"}

      assert {:ok, date} =
               impl
               |> RuleResult.changeset(params)
               |> Changeset.fetch_change(:date)

      assert date == @datetime
    end

    test "accepts row_number" do
      impl = insert(:implementation)
      params = %{"row_number" => 123}

      assert {:ok, row_number} =
               impl
               |> RuleResult.changeset(params)
               |> Changeset.fetch_change(:row_number)

      assert row_number == 123
    end

    test "accepts large values in errors and records fields" do
      impl = insert(:implementation)
      {errors, records} = {4_715_670_290, 9_223_372_036_854_775_807}
      %{id: rule_id} = insert(:rule)

      params =
        string_params_for(:rule_result,
          records: records,
          result_type: "percentage",
          errors: errors,
          result: 0
        )

      assert {:ok, %{id: id}} =
               %RuleResult{rule_id: rule_id}
               |> RuleResult.changeset(impl, params)
               |> Repo.insert()

      assert %{errors: ^errors, records: ^records} = Repo.get!(RuleResult, id)
    end

    test "result_type percentage: puts calculated result if not present in changeset" do
      impl = insert(:implementation)
      {errors, records} = {123_456, 456_123}

      params = %{
        "records" => records,
        "errors" => errors,
        "implementation_id" => 10,
        "date" => "2020-01-01",
        "result_type" => "percentage"
      }

      assert "72.93" =
               impl
               |> RuleResult.changeset(params)
               |> Changeset.get_change(:result)
               |> Decimal.to_string()
    end

    test "result_type deviation: puts calculated result if not present in changeset" do
      impl = insert(:implementation)
      {errors, records} = {123_456, 456_123}

      params = %{
        "records" => records,
        "errors" => errors,
        "implementation_id" => 10,
        "date" => "2020-01-01",
        "result_type" => "deviation"
      }

      assert "27.06" =
               impl
               |> RuleResult.changeset(params)
               |> Changeset.get_change(:result)
               |> Decimal.to_string()
    end

    test "result_type: does not put calculated result if already present in changeset" do
      impl = insert(:implementation)
      {errors, records, result} = {123_456, 456_123, 12.34}

      params = %{
        "records" => records,
        "errors" => errors,
        "result" => result,
        "implementation_id" => 10,
        "date" => "2020-01-01",
        "result_type" => "percentage"
      }

      result_string = "#{result}"

      assert ^result_string =
               impl
               |> RuleResult.changeset(params)
               |> Changeset.get_change(:result)
               |> Decimal.to_string()
    end

    test "accepts string values for errors and records" do
      impl = insert(:implementation)
      params = %{"errors" => "123456", "records" => "654321"}
      changeset = RuleResult.changeset(impl, params)
      assert Changeset.fetch_change!(changeset, :errors) == 123_456
      assert Changeset.fetch_change!(changeset, :records) == 654_321
    end

    test "validates errors and records are non-negative if present" do
      impl = insert(:implementation)
      params = %{"errors" => -1, "records" => -2}
      assert %{errors: errors} = RuleResult.changeset(impl, params)

      assert {_, [validation: :number, kind: :greater_than_or_equal_to, number: 0]} =
               errors[:errors]

      assert {_, [validation: :number, kind: :greater_than_or_equal_to, number: 0]} =
               errors[:records]
    end

    test "rounds result to two decimal places" do
      impl = insert(:implementation)
      params = %{"result" => 123.456_789}

      assert "123.45" ==
               impl
               |> RuleResult.changeset(params)
               |> Changeset.get_change(:result)
               |> Decimal.to_string()
    end
  end
end
