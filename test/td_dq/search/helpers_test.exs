defmodule TdDq.Search.HelpersTest do
  use TdDd.DataCase

  alias TdDq.Search.Helpers

  @moduletag sandbox: :shared

  setup do
    start_supervised!(TdDd.Search.StructureEnricher)
    :ok
  end

  describe "get_sources/1" do
    test "extracts aliases from structure metadata" do
      ids =
        [%{}, %{"alias" => "foo"}, %{"alias" => "foo"}, %{"alias" => "bar"}]
        |> Enum.map(&insert(:data_structure_version, metadata: &1))
        |> Enum.map(& &1.data_structure_id)

      assert Helpers.get_sources(ids) == ["foo", "bar"]
    end
  end

  describe "with_result_text/4" do
    test "percentage, under_minimum" do
      result_map = %{
        date: ~U[2021-08-06 01:34:00Z],
        result: Decimal.new(79)
      }

      result_text =
        Helpers.with_result_text(result_map, 80, 90, "percentage")
        |> Map.get(:result_text)

      assert result_text == "quality_result.under_minimum"
    end

    test "percentage, under_goal (eq to minimum)" do
      result_map = %{
        date: ~U[2021-08-06 01:34:00Z],
        result: Decimal.new(80)
      }

      result_text =
        Helpers.with_result_text(result_map, 80, 90, "percentage")
        |> Map.get(:result_text)

      assert result_text == "quality_result.under_goal"
    end

    test "percentage, under_goal (past minimum)" do
      result_map = %{
        date: ~U[2021-08-06 01:34:00Z],
        result: Decimal.new(85)
      }

      result_text =
        Helpers.with_result_text(result_map, 80, 90, "percentage")
        |> Map.get(:result_text)

      assert result_text == "quality_result.under_goal"
    end

    test "percentage, over_goal (eq to goal)" do
      result_map = %{
        date: ~U[2021-08-06 01:34:00Z],
        result: Decimal.new(90)
      }

      result_text =
        Helpers.with_result_text(result_map, 80, 90, "percentage")
        |> Map.get(:result_text)

      assert result_text == "quality_result.over_goal"
    end

    test "percentage, over_goal" do
      result_map = %{
        date: ~U[2021-08-06 01:34:00Z],
        result: Decimal.new(91)
      }

      result_text =
        Helpers.with_result_text(result_map, 80, 90, "percentage")
        |> Map.get(:result_text)

      assert result_text == "quality_result.over_goal"
    end

    test "percentage, without records" do
      result_map = %{
        date: ~U[2021-08-06 01:34:00Z],
        records: 0
      }

      result_text =
        Helpers.with_result_text(result_map, 0, 0, "percentage")
        |> Map.get(:result_text)

      assert result_text == "quality_result.empty_dataset"
    end

    test "deviation, under_minimum" do
      result_map = %{
        date: ~U[2021-08-06 01:34:00Z],
        result: Decimal.new(21)
      }

      result_text =
        Helpers.with_result_text(result_map, 20, 10, "deviation")
        |> Map.get(:result_text)

      assert result_text == "quality_result.under_minimum"
    end

    test "deviation, under_goal (eq to minimum)" do
      result_map = %{
        date: ~U[2021-08-06 01:34:00Z],
        result: Decimal.new(20)
      }

      result_text =
        Helpers.with_result_text(result_map, 20, 10, "deviation")
        |> Map.get(:result_text)

      assert result_text == "quality_result.under_goal"
    end

    test "deviation, under_goal (past minimum)" do
      result_map = %{
        date: ~U[2021-08-06 01:34:00Z],
        result: Decimal.new(15)
      }

      result_text =
        Helpers.with_result_text(result_map, 20, 10, "deviation")
        |> Map.get(:result_text)

      assert result_text == "quality_result.under_goal"
    end

    test "deviation, over_goal (eq to goal)" do
      result_map = %{
        date: ~U[2021-08-06 01:34:00Z],
        result: Decimal.new(10)
      }

      result_text =
        Helpers.with_result_text(result_map, 20, 10, "deviation")
        |> Map.get(:result_text)

      assert result_text == "quality_result.over_goal"
    end

    test "deviation, over_goal (past goal)" do
      result_map = %{
        date: ~U[2021-08-06 01:34:00Z],
        result: Decimal.new(9)
      }

      result_text =
        Helpers.with_result_text(result_map, 20, 10, "deviation")
        |> Map.get(:result_text)

      assert result_text == "quality_result.over_goal"
    end

    test "deviation without records" do
      result_map = %{
        date: ~U[2021-08-06 01:34:00Z],
        records: 0
      }

      result_text =
        Helpers.with_result_text(result_map, 0, 0, "deviation")
        |> Map.get(:result_text)

      assert result_text == "quality_result.empty_dataset"
    end

    test "errors_number, under_minimum" do
      result_map = %{
        date: ~U[2021-08-06 01:34:00Z],
        errors: 131
      }

      result_text =
        Helpers.with_result_text(result_map, 130, 120, "errors_number")
        |> Map.get(:result_text)

      assert result_text == "quality_result.under_minimum"
    end

    test "errors_number, under_goal (eq to minimum)" do
      result_map = %{
        date: ~U[2021-08-06 01:34:00Z],
        errors: 130
      }

      result_text =
        Helpers.with_result_text(result_map, 130, 120, "errors_number")
        |> Map.get(:result_text)

      assert result_text == "quality_result.under_goal"
    end

    test "errors_number, under_goal (past minimum)" do
      result_map = %{
        date: ~U[2021-08-06 01:34:00Z],
        errors: 125
      }

      result_text =
        Helpers.with_result_text(result_map, 130, 120, "errors_number")
        |> Map.get(:result_text)

      assert result_text == "quality_result.under_goal"
    end

    test "errors_number, over_goal (eq to goal)" do
      result_map = %{
        date: ~U[2021-08-06 01:34:00Z],
        errors: 120
      }

      result_text =
        Helpers.with_result_text(result_map, 130, 120, "errors_number")
        |> Map.get(:result_text)

      assert result_text == "quality_result.over_goal"
    end

    test "errors_number, over_goal (past goal)" do
      result_map = %{
        date: ~U[2021-08-06 01:34:00Z],
        errors: 119
      }

      result_text =
        Helpers.with_result_text(result_map, 130, 120, "errors_number")
        |> Map.get(:result_text)

      assert result_text == "quality_result.over_goal"
    end

    test "errors_number without records" do
      result_map = %{
        date: ~U[2021-08-06 01:34:00Z],
        records: 0
      }

      result_text =
        Helpers.with_result_text(result_map, 0, 0, "errors_number")
        |> Map.get(:result_text)

      assert result_text == "quality_result.empty_dataset"
    end
  end
end
