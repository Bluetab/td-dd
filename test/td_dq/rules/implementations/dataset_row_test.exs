defmodule TdDq.Rules.Implementations.DatasetRowTest do
  use TdDd.DataCase

  alias Ecto.Changeset
  alias TdDq.Rules.Implementations.DatasetRow

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
  end
end
