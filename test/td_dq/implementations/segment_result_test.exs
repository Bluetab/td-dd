defmodule TdDq.Rules.SegmentResultTest do
  # use TdDd.DataCase

  # alias Ecto.Changeset
  # alias TdDd.Repo
  # alias TdDq.Implementations.SegmentResult

  # setup do
  #   %{id: rule_id} = insert(:rule)
  #   rule_result = insert(:rule_result, rule_id: rule_id, result_type: "percentage")
  #   [rule_result: rule_result, rule_id: rule_id]
  # end

  # describe "changeset/2" do
  #   test "accepts large values in errors and records fields", %{
  #     rule_result: %{id: rule_result_id} = rule_result
  #   } do
  #     {errors, records} = {4_715_670_290, 9_223_372_036_854_775_807}

  #     params =
  #       string_params_for(:segment_result,
  #         records: records,
  #         errors: errors,
  #         result: 0
  #       )

  #     assert {:ok, %{id: id}} =
  #              %SegmentResult{rule_result_id: rule_result_id}
  #              |> SegmentResult.changeset(rule_result, params)
  #              |> Repo.insert()

  #     assert %{errors: ^errors, records: ^records} = Repo.get!(SegmentResult, id)
  #   end

  #   test "result_type percentage: puts calculated result if not present in changeset", %{
  #     rule_id: rule_id
  #   } do
  #     %{id: rule_result_id} =
  #       rule_result = insert(:rule_result, rule_id: rule_id, result_type: "percentage")

  #     {errors, records} = {123_456, 456_123}

  #     params = %{
  #       "records" => records,
  #       "errors" => errors,
  #       "rule_result_id" => rule_result_id
  #     }

  #     assert "72.93" =
  #              rule_result
  #              |> SegmentResult.changeset(params)
  #              |> Changeset.get_change(:result)
  #              |> Decimal.to_string()
  #   end

  #   test "result_type deviation: puts calculated result if not present in changeset", %{
  #     rule_id: rule_id
  #   } do
  #     %{id: rule_result_id} =
  #       rule_result = insert(:rule_result, rule_id: rule_id, result_type: "deviation")

  #     {errors, records} = {123_456, 456_123}

  #     params = %{
  #       "records" => records,
  #       "errors" => errors,
  #       "rule_result_id" => rule_result_id
  #     }

  #     assert "27.06" =
  #              rule_result
  #              |> SegmentResult.changeset(params)
  #              |> Changeset.get_change(:result)
  #              |> Decimal.to_string()
  #   end

  #   test "result_type: does not put calculated result if already present in changeset", %{rule_result: %{id: rule_result_id} = rule_result} do

  #     {errors, records, result} = {123_456, 456_123, 12.34}

  #     params = %{
  #       "records" => records,
  #       "errors" => errors,
  #       "result" => result,
  #       "rule_result_id" => rule_result_id
  #     }

  #     result_string = "#{result}"

  #     assert ^result_string =
  #           rule_result
  #              |> SegmentResult.changeset(params)
  #              |> Changeset.get_change(:result)
  #              |> Decimal.to_string()
  #   end

  #   test "accepts string values for errors and records" do
  #     rule_result = insert(:rule_result)
  #     params = %{"errors" => "123456", "records" => "654321"}
  #     changeset = SegmentResult.changeset(rule_result, params)
  #     assert Changeset.fetch_change!(changeset, :errors) == 123_456
  #     assert Changeset.fetch_change!(changeset, :records) == 654_321
  #   end

  #   test "validates errors and records are non-negative if present" do
  #     rule_result = insert(:rule_result)
  #     params = %{"errors" => -1, "records" => -2}
  #     assert %{errors: errors} = SegmentResult.changeset(rule_result, params)

  #     assert {_, [validation: :number, kind: :greater_than_or_equal_to, number: 0]} =
  #              errors[:errors]

  #     assert {_, [validation: :number, kind: :greater_than_or_equal_to, number: 0]} =
  #              errors[:records]
  #   end

  #   test "rounds result to two decimal places" do
  #     rule_result = insert(:rule_result)
  #     params = %{"result" => 123.456_789}

  #     assert "123.45" ==
  #       rule_result
  #              |> SegmentResult.changeset(params)
  #              |> Changeset.get_change(:result)
  #              |> Decimal.to_string()
  #   end
  # end
end
