defmodule TdDd.ReferenceData.DatasetTest do
  use ExUnit.Case

  alias Ecto.Changeset
  alias TdDd.ReferenceData.Dataset

  describe "Dataset.changeset/2" do
    test "validates data is not empty" do
      params = %{
        name: "dataset1",
        data: []
      }

      assert %{valid?: false, errors: errors} = Dataset.changeset(params)
      assert errors[:data] == {"can't be empty", []}
    end

    test "validates data has more than one row" do
      params = %{
        name: "dataset1",
        data: [["foo", "bar"]]
      }

      assert %{valid?: false, errors: errors} = Dataset.changeset(params)
      assert errors[:data] == {"must have at least one row", []}
    end

    test "validates rows have consistent lengths" do
      params = %{
        name: "dataset1",
        data: [["foo", "bar"], ["foo", "bar", "baz"]]
      }

      assert %{valid?: false, errors: errors} = Dataset.changeset(params)
      assert errors[:data] == {"inconsistent length", []}
    end

    test "removes empty rows from data" do
      params = %{
        name: "dataset1",
        data: [["foo", "bar"], ["foo1", "bar1"], [""], []]
      }

      assert %{valid?: true} = changeset = Dataset.changeset(params)
      assert Changeset.fetch_field!(changeset, :rows) == [["foo1", "bar1"]]
    end

    test "validates maximum rows" do
      Application.put_env(:td_dd, TdDd.ReferenceData, max_rows: 2)

      params = %{
        name: "dataset1",
        data: [["foo", "bar"], ["foo1", "bar1"], ["foo2", "bar2"]]
      }

      assert %{valid?: false, errors: errors} = Dataset.changeset(params)
      assert errors[:data] == {"maximum 2 rows", []}
    end

    test "validates maximum columns" do
      Application.put_env(:td_dd, TdDd.ReferenceData, max_rows: 10, max_cols: 2)

      params = %{
        name: "dataset1",
        data: [["foo", "bar", "baz"], ["foo1", "bar1", "baz1"]]
      }

      assert %{valid?: false, errors: errors} = Dataset.changeset(params)
      assert errors[:data] == {"maximum 2 columns", []}
    end

    test "validates cast unique domain_ids" do
      params = %{
        name: "dataset1",
        data: [["foo", "bar"], ["foo1", "bar1"]],
        domain_ids: [1, 1]
      }

      assert %{valid?: true, changes: %{domain_ids: [1]}} = Dataset.changeset(params)
    end
  end
end
