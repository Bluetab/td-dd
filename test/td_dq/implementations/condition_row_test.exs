defmodule TdDq.Implementations.ConditionRowTest do
  use TdDd.DataCase

  alias TdDq.Implementations.ConditionRow

  describe "changeset/2" do
    test "validates value is a valid attribute" do
      params = string_params_for(:condition_row, value: [%{id: "whatever"}])

      assert %{valid?: false, errors: errors} = ConditionRow.changeset(params)
      assert {"invalid_attribute", [validation: :invalid]} = errors[:value]
    end

    test "validates value is a valid range when operator is between dates" do
      operator = %{name: "between", value_type: "date"}

      params =
        string_params_for(:condition_row,
          value: [%{raw: "2019-12-10"}, %{raw: "2019-11-30"}],
          operator: operator
        )

      assert %{valid?: false, errors: errors} = ConditionRow.changeset(params)

      assert {"invalid.range.dates", [validation: :left_value_must_be_le_than_right]} =
               errors[:value]
    end

    test "validates value is a valid range when operator is between timestamps" do
      operator = %{name: "between", value_type: "timestamp"}

      params =
        string_params_for(:condition_row,
          value: [%{raw: "2019-12-03 05:15:00"}, %{raw: "2019-12-02 02:10:30"}],
          operator: operator
        )

      assert %{valid?: false, errors: errors} = ConditionRow.changeset(params)

      assert {"invalid.range.dates", [validation: :left_value_must_be_le_than_right]} =
               errors[:value]
    end

    test "validates operator is present" do
      params = string_params_for(:condition_row) |> Map.delete("operator")

      assert %{valid?: false, errors: errors} = ConditionRow.changeset(params)
      assert {"can't be blank", [validation: :required]} = errors[:operator]
    end
  end

  test "validates empty value" do
    params = string_params_for(:condition_row, value: [])

    assert %{valid?: true} = ConditionRow.changeset(params)
  end
end
