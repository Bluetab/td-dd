defmodule TdDq.Implementations.DatasetRowTest do
  use TdDd.DataCase

  alias Ecto.Changeset
  alias TdDq.Implementations.DatasetRow

  describe "changeset/2" do
    test "validates clauses is non-empty if join_type is specified" do
      params = string_params_for(:dataset_row, clauses: [], join_type: "inner")

      assert %{valid?: false, errors: errors} = DatasetRow.changeset(params)
      assert {"can't be blank", [validation: :required]} = errors[:clauses]
    end

    test "validates clause required fields" do
      params = string_params_for(:dataset_row, clauses: [%{}], join_type: "inner")

      assert %{valid?: false} = changeset = DatasetRow.changeset(params)
      assert %{clauses: [errors]} = Changeset.traverse_errors(changeset, & &1)
      assert [{"can't be blank", [validation: :required]}] = errors[:left]
      assert [{"can't be blank", [validation: :required]}] = errors[:right]
    end

    test "only accepts valid join_types" do
      clause_params = [
        %{
          left: string_params_for(:dataset_structure),
          right: string_params_for(:dataset_structure)
        }
      ]

      valid_params = string_params_for(:dataset_row, clauses: clause_params, join_type: "inner")
      invalid_params = valid_params |> Map.put("join_type", "unknown")
      another_valid_params = valid_params |> Map.put("join_type", "right")

      assert %{valid?: true} = DatasetRow.changeset(valid_params)
      assert %{valid?: false} = DatasetRow.changeset(invalid_params)
      assert %{valid?: true} = DatasetRow.changeset(another_valid_params)
    end
  end
end
