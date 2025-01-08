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
      max_rows = Application.get_env(:td_dd, TdDd.ReferenceData)[:max_rows]

      data = for _ <- 1..(max_rows + 1), do: ["foo", "bar"]

      params = %{
        name: "dataset1",
        data: data
      }

      assert %{valid?: false, errors: errors} = Dataset.changeset(params)
      assert errors[:data] == {"maximum #{max_rows} rows", []}
    end

    test "validates maximum columns" do
      max_cols = Application.get_env(:td_dd, TdDd.ReferenceData)[:max_cols]

      row = for i <- 1..(max_cols + 1), do: "col#{i}"

      params = %{
        name: "dataset1",
        data: [row, row]
      }

      assert %{valid?: false, errors: errors} = Dataset.changeset(params)
      assert errors[:data] == {"maximum #{max_cols} columns", []}
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
