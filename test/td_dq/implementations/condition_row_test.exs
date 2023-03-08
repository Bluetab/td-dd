defmodule TdDq.Implementations.ConditionRowTest do
  use TdDd.DataCase

  alias TdDq.Implementations.ConditionRow

  describe "changeset/2" do
    test "validates value is a valid attribute" do
      params = string_params_for(:condition_row, value: [%{id: "whatever"}])

      assert %{valid?: false, errors: errors} = ConditionRow.changeset(params)
      assert {"invalid_attribute", [validation: :invalid]} = errors[:value]
    end

    test "validates value reference_dataset_field is a valid attribute" do
      params = string_params_for(:condition_row, value: [%{type: "reference_dataset_field"}])

      assert %{valid?: false, errors: errors} = ConditionRow.changeset(params)
      assert {"invalid_attribute", [validation: :invalid]} = errors[:value]

      params =
        string_params_for(:condition_row,
          value: [
            %{
              type: "reference_dataset_field",
              name: "field_name"
            }
          ]
        )

      assert %{valid?: false, errors: errors} = ConditionRow.changeset(params)
      assert {"invalid_attribute", [validation: :invalid]} = errors[:value]

      params =
        string_params_for(:condition_row,
          value: [
            %{
              type: "reference_dataset_field",
              name: "",
              parent_index: 4
            }
          ]
        )

      assert %{valid?: false, errors: errors} = ConditionRow.changeset(params)
      assert {"invalid_attribute", [validation: :invalid]} = errors[:value]

      params =
        string_params_for(:condition_row,
          value: [
            %{
              type: "reference_dataset_field",
              name: "field_name",
              parent_index: 4
            }
          ]
        )

      assert %{valid?: true} = ConditionRow.changeset(params)
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

    test "validates modifier is cast" do
      params =
        :condition_row
        |> string_params_for()
        |> Map.put("modifier", string_params_for(:modifier))

      assert %{
               valid?: true,
               changes: %{modifier: %{valid?: true}}
             } = ConditionRow.changeset(params)
    end

    test "validates value_modifier is cast" do
      params =
        :condition_row
        |> string_params_for()
        |> Map.put("value_modifier", [string_params_for(:modifier)])

      assert %{
               valid?: true,
               changes: %{value_modifier: [%{valid?: true}]}
             } = ConditionRow.changeset(params)
    end
  end

  test "validates empty value" do
    params = string_params_for(:condition_row, value: [])

    assert %{valid?: true} = ConditionRow.changeset(params)
  end

  test "field_list: valid, operator arity 1" do
    params =
      string_params_for(
        :condition_row,
        value: [%{fields: [%{id: 1}, %{id: 2}, %{id: 3}]}],
        operator: %{name: "unique", value_type: "field_list"}
      )

    assert %{valid?: true} = ConditionRow.changeset(params)
  end

  test "field list: valid, operator arity 2" do
    params =
      string_params_for(
        :condition_row,
        value: [
          %{fields: [%{id: 1}, %{id: 2}, %{id: 3}]},
          %{fields: [%{id: 4}, %{id: 5}, %{id: 6}]}
        ],
        operator: %{name: "some_arity_2_operator", value_type: "field_list", arity: 2}
      )

    assert %{valid?: true} = ConditionRow.changeset(params)
  end

  test "field_list: check invalid field (not a list)" do
    params =
      string_params_for(
        :condition_row,
        value: [%{fields: %{id: "1"}}],
        operator: %{name: "unique", value_type: "field_list"}
      )

    assert %{valid?: false, errors: errors} = ConditionRow.changeset(params)
    assert {"invalid_attribute", [validation: :invalid]} = errors[:value]
  end

  test "field_list: check invalid field (string id)" do
    params =
      string_params_for(
        :condition_row,
        value: [%{fields: [%{id: "1"}, %{id: "a_string"}, %{id: 3}]}],
        operator: %{name: "unique", value_type: "field_list"}
      )

    assert %{valid?: false, errors: errors} = ConditionRow.changeset(params)
    assert {"invalid_attribute", [validation: :invalid]} = errors[:value]
  end

  test "field_list: allows valid reference_dataset_field (reference dataset from parent_index)" do
    params =
      string_params_for(
        :condition_row,
        value: [
          %{
            fields: [%{name: "field", type: "reference_dataset_field", parent_index: 2}, %{id: 3}]
          }
        ],
        operator: %{name: "unique", value_type: "field_list"}
      )

    assert %{valid?: true} = ConditionRow.changeset(params)
  end

  test "field_list: allows valid reference_dataset_field (reference dataset included in parameters)" do
    params =
      string_params_for(
        :condition_row,
        value: [
          %{
            fields: [
              %{
                name: "field",
                type: "reference_dataset_field",
                referenceDataset: %{id: 1, name: "some_reference_dataset_field"}
              },
              %{id: 3}
            ]
          }
        ],
        operator: %{name: "unique", value_type: "field_list"}
      )

    assert %{valid?: true} = ConditionRow.changeset(params)
  end

  test "field_list: check for invalid reference_dataset_field" do
    params =
      string_params_for(
        :condition_row,
        value: [%{fields: [%{name: "field", type: "reference_dataset_field"}, %{id: 3}]}],
        operator: %{name: "unique", value_type: "field_list"}
      )

    assert %{valid?: false, errors: errors} = ConditionRow.changeset(params)
    assert {"invalid_attribute", [validation: :invalid]} = errors[:value]
  end

  test "field_list: check fields not contained in 'fields' map" do
    params =
      string_params_for(
        :condition_row,
        value: [[%{id: 1}, %{id: 2}, %{id: 3}]],
        operator: %{name: "unique", value_type: "field_list"}
      )

    assert %{valid?: false, errors: errors} = ConditionRow.changeset(params)
    assert {"is invalid", [type: {:array, :map}, validation: :cast]} = errors[:value]
  end
end
